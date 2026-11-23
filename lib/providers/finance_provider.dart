import 'dart:async';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';
import '../services/local_cache.dart';
import '../services/sync_queue.dart';

class FinanceProvider extends ChangeNotifier {
  static const int pageSize = 50;
  final _repo = TransactionRepository();

  List<AppTransaction> _transactions = [];
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  TransactionType? _typeFilter;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _hasLoadedOnce = false;
  DateTime? _lastFetchedAt;
  String? _error;

  // Aggregates for selected month
  int _incomeCents = 0;
  int _expenseCents = 0;

  List<AppTransaction> get allTransactions => _transactions;

  List<AppTransaction> get transactions {
    var list = _transactions;
    if (_typeFilter != null) {
      list = list.where((t) => t.type == _typeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((t) =>
              (t.description?.toLowerCase().contains(q) ?? false) ||
              (t.category?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  int get incomeCents => _incomeCents;
  int get expenseCents => _expenseCents;
  int get netCents => _incomeCents - _expenseCents;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;
  TransactionType? get typeFilter => _typeFilter;
  bool get isLoading => _isLoading && _transactions.isEmpty;
  bool get isRefreshing => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  /// Real operation counts for the selected month (independent of pagination).
  ({int total, int income, int expense})? _counts;
  int get totalCount => _counts?.total ?? _transactions.length;
  int get incomeCount =>
      _counts?.income ??
      _transactions.where((t) => t.type == TransactionType.income).length;
  int get expenseCount =>
      _counts?.expense ??
      _transactions.where((t) => t.type == TransactionType.expense).length;

  String _cacheKey(int year, int month) => 'tx_page1_${year}_$month';

  void _recomputeLocalTotals() {
    _incomeCents = _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0, (sum, t) => sum + t.amountCents);
    _expenseCents = _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0, (sum, t) => sum + t.amountCents);
  }

  Future<void> hydrateFromCache() async {
    if (_hasLoadedOnce && _transactions.isNotEmpty) return;
    final y = _selectedYear;
    final m = _selectedMonth;
    final results = await Future.wait([
      LocalCache.readMap('${_cacheKey(y, m)}_counts'),
      LocalCache.readMap(_cacheKey(y, m)),
    ]);
    final c = results[0];
    if (c != null) {
      _counts = (
        total: (c['total'] as num?)?.toInt() ?? 0,
        income: (c['income'] as num?)?.toInt() ?? 0,
        expense: (c['expense'] as num?)?.toInt() ?? 0,
      );
    }
    final cached = results[1];
    if (cached != null) {
      final rawItems = (cached['items'] as List?) ?? const [];
      _transactions = rawItems
          .map((e) =>
              AppTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _hasMore = cached['hasMore'] == true;
      _incomeCents = (cached['incomeCents'] as num?)?.toInt() ?? 0;
      _expenseCents = (cached['expenseCents'] as num?)?.toInt() ?? 0;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  void applyBootstrapPayload(
    Map<String, dynamic> json, {
    required int year,
    required int month,
  }) {
    _selectedYear = year;
    _selectedMonth = month;
    final rawItems = (json['items'] as List?) ?? const [];
    _transactions = rawItems
        .map((e) => AppTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    _hasMore = json['hasMore'] == true;
    _hasLoadedOnce = true;
    _isLoading = false;
    _lastFetchedAt = DateTime.now();

    final rawCounts = json['counts'];
    if (rawCounts is Map) {
      _counts = (
        total: (rawCounts['total'] as num?)?.toInt() ?? _transactions.length,
        income: (rawCounts['income'] as num?)?.toInt() ?? 0,
        expense: (rawCounts['expense'] as num?)?.toInt() ?? 0,
      );
      unawaited(LocalCache.writeMap('${_cacheKey(year, month)}_counts', {
        'total': _counts!.total,
        'income': _counts!.income,
        'expense': _counts!.expense,
      }));
    }

    _incomeCents = (json['incomeCents'] as num?)?.toInt() ?? 0;
    _expenseCents = (json['expenseCents'] as num?)?.toInt() ?? 0;
    notifyListeners();

    unawaited(LocalCache.writeMap(_cacheKey(year, month), {
      'items': _transactions.map((t) => t.toMap()).toList(),
      'hasMore': _hasMore,
      'incomeCents': _incomeCents,
      'expenseCents': _expenseCents,
    }));
  }

  /// Loads the first page (50 items) + monthly totals + counts in a SINGLE HTTP request.
  /// Shows cached snapshot immediately if available.
  Future<void> loadMonth(
    int year,
    int month, {
    bool silent = false,
    bool force = false,
  }) async {
    final monthChanged = year != _selectedYear || month != _selectedMonth;
    _selectedYear = year;
    _selectedMonth = month;

    if (!force &&
        !monthChanged &&
        _hasLoadedOnce &&
        _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!) <
            const Duration(seconds: 20)) {
      return;
    }

    if (monthChanged) {
      _transactions = [];
      _hasMore = false;
      _counts = null;
    }

    if (_counts == null) {
      final c = await LocalCache.readMap('${_cacheKey(year, month)}_counts');
      if (c != null) {
        _counts = (
          total: (c['total'] as num?)?.toInt() ?? 0,
          income: (c['income'] as num?)?.toInt() ?? 0,
          expense: (c['expense'] as num?)?.toInt() ?? 0,
        );
      }
    }

    // Show local snapshot immediately if list is currently empty
    if (_transactions.isEmpty) {
      final cached = await LocalCache.readMap(_cacheKey(year, month));
      if (cached != null) {
        final rawItems = (cached['items'] as List?) ?? const [];
        _transactions = rawItems
            .map((e) =>
                AppTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _hasMore = cached['hasMore'] == true;
        _incomeCents = (cached['incomeCents'] as num?)?.toInt() ?? 0;
        _expenseCents = (cached['expenseCents'] as num?)?.toInt() ?? 0;
        notifyListeners();
      }
    }

    if (_isLoading && !monthChanged) return;
    if (!silent && _transactions.isEmpty) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    } else {
      _isLoading = true;
      _error = null;
    }

    try {
      final page = await _repo.getMonthPage(
        year,
        month,
        skip: 0,
        limit: pageSize,
        includeSummary: true,
      );
      _transactions = page.items;
      _hasMore = page.hasMore;
      _hasLoadedOnce = true;
      _lastFetchedAt = DateTime.now();

      if (page.counts != null) {
        _counts = page.counts;
        unawaited(LocalCache.writeMap('${_cacheKey(year, month)}_counts', {
          'total': page.counts!.total,
          'income': page.counts!.income,
          'expense': page.counts!.expense,
        }));
      } else {
        unawaited(refreshCounts());
      }

      if (page.incomeCents != null && page.expenseCents != null) {
        _incomeCents = page.incomeCents!;
        _expenseCents = page.expenseCents!;
      } else {
        _recomputeLocalTotals();
      }

      // Persist first page snapshot for instant future open
      unawaited(LocalCache.writeMap(_cacheKey(year, month), {
        'items': _transactions.map((t) => t.toMap()).toList(),
        'hasMore': _hasMore,
        'incomeCents': _incomeCents,
        'expenseCents': _expenseCents,
      }));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes real operation counts for the selected month from the server.
  Future<void> refreshCounts() async {
    final y = _selectedYear;
    final m = _selectedMonth;
    try {
      final c = await _repo.getMonthCounts(y, m);
      if (y != _selectedYear || m != _selectedMonth) return;
      _counts = c;
      unawaited(LocalCache.writeMap('${_cacheKey(y, m)}_counts', {
        'total': c.total,
        'income': c.income,
        'expense': c.expense,
      }));
      notifyListeners();
    } catch (_) {}
  }

  /// Loads the remaining pages of the selected month in the background so
  /// lists, filters and counters reflect everything that really exists.
  Future<void> loadAll({int maxPages = 40}) async {
    final y = _selectedYear;
    final m = _selectedMonth;
    var guard = 0;
    while (_hasMore && guard++ < maxPages) {
      if (y != _selectedYear || m != _selectedMonth) return;
      if (_isLoadingMore) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        continue;
      }
      final before = _transactions.length;
      await loadMore();
      if (_transactions.length == before) break;
    }
  }

  /// Loads the next 25 transactions as the user scrolls down.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _repo.getMonthPage(
        _selectedYear,
        _selectedMonth,
        skip: _transactions.length,
        limit: pageSize,
        includeSummary: false,
      );
      final existingIds = _transactions.map((t) => t.id).toSet();
      final fresh = page.items.where((t) => !existingIds.contains(t.id));
      _transactions = [..._transactions, ...fresh];
      _hasMore = page.hasMore;
    } catch (_) {
      // Keep existing loaded list on transient error
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Loads all transactions for a month (used by full-month category report charts).
  Future<void> loadMonthFull(int year, int month) async {
    _selectedYear = year;
    _selectedMonth = month;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _repo.getMonthPage(
        year,
        month,
        skip: 0,
        limit: 500,
        includeSummary: true,
      );
      final all = [...page.items];
      var guard = 0;
      var more = page.hasMore;
      while (more && guard++ < 50) {
        final next = await _repo.getMonthPage(
          year,
          month,
          skip: all.length,
          limit: 500,
        );
        all.addAll(next.items);
        more = next.hasMore && next.items.isNotEmpty;
      }
      _transactions = all;
      _counts = (
        total: all.length,
        income: all.where((t) => t.type == TransactionType.income).length,
        expense: all.where((t) => t.type == TransactionType.expense).length,
      );
      _hasMore = false;
      _hasLoadedOnce = true;
      if (page.incomeCents != null && page.expenseCents != null) {
        _incomeCents = page.incomeCents!;
        _expenseCents = page.expenseCents!;
      } else {
        _recomputeLocalTotals();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Low-priority background prefetch after active screen finishes rendering.
  Future<void> prefetchIfNeeded() async {
    if (_hasLoadedOnce || _isLoading) return;
    await loadMonth(_selectedYear, _selectedMonth, silent: true);
  }

  Future<void> reload() => loadMonth(_selectedYear, _selectedMonth, force: true);

  void setTypeFilter(TransactionType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
    if (query.trim().isNotEmpty && _hasMore) {
      unawaited(loadAll());
    }
  }

  // ── Optimistic writes: UI updates in the same frame, server sync in background.

  ({List<AppTransaction> list, int income, int expense}) _snapshot() =>
      (list: List<AppTransaction>.of(_transactions), income: _incomeCents, expense: _expenseCents);

  void _restore(({List<AppTransaction> list, int income, int expense}) s) {
    _transactions = s.list;
    _incomeCents = s.income;
    _expenseCents = s.expense;
    notifyListeners();
  }

  Future<void> _reloadCurrent() =>
      loadMonth(_selectedYear, _selectedMonth, silent: true, force: true);

  Future<void> add(AppTransaction tx) async {
    final before = _snapshot();
    if (tx.date.year == _selectedYear && tx.date.month == _selectedMonth) {
      _transactions = [tx, ..._transactions];
      if (tx.type == TransactionType.income) {
        _incomeCents += tx.amountCents;
      } else {
        _expenseCents += tx.amountCents;
      }
      notifyListeners();
    }
    SyncQueue.background(
      () => _repo.insert(tx),
      onError: (_) => _restore(before),
      onSuccess: _reloadCurrent,
    );
  }

  Future<void> update(AppTransaction tx) async {
    final before = _snapshot();
    final idx = _transactions.indexWhere((t) => t.id == tx.id);
    if (idx != -1) {
      _transactions = List<AppTransaction>.of(_transactions)..[idx] = tx;
      _recomputeLocalTotals();
      notifyListeners();
    }
    SyncQueue.background(
      () => _repo.update(tx),
      onError: (_) => _restore(before),
      onSuccess: _reloadCurrent,
    );
  }

  Future<void> delete(String id) async {
    final before = _snapshot();
    final removed = _transactions.where((t) => t.id == id).firstOrNull;
    _transactions = _transactions.where((t) => t.id != id).toList();
    if (removed != null) {
      if (removed.type == TransactionType.income) {
        _incomeCents = (_incomeCents - removed.amountCents).clamp(0, 1 << 62);
      } else {
        _expenseCents = (_expenseCents - removed.amountCents).clamp(0, 1 << 62);
      }
    }
    notifyListeners();
    SyncQueue.background(
      () => _repo.delete(id),
      onError: (_) => _restore(before),
      onSuccess: refreshCounts,
    );
  }

  /// Returns daily chart data for the selected month.
  Future<List<Map<String, dynamic>>> getDailyTotals() =>
      _repo.getDailyTotals(_selectedYear, _selectedMonth);

  /// Returns recent transactions across all time (for dashboard).
  Future<List<AppTransaction>> getRecent({int limit = 10}) async {
    final page = await _repo.getMonthPage(
      _selectedYear,
      _selectedMonth,
      limit: limit,
    );
    return page.items.take(limit).toList();
  }

  Future<AppTransaction?> getById(String id) async {
    final local = _transactions.where((t) => t.id == id).firstOrNull;
    if (local != null) return local;
    final all = await _repo.getAll();
    return all.where((t) => t.id == id).firstOrNull;
  }
}
