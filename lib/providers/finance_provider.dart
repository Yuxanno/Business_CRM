import 'dart:async';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';
import '../services/local_cache.dart';

class FinanceProvider extends ChangeNotifier {
  static const int pageSize = 25;
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

  /// Loads the first page (25 items) + monthly totals in a SINGLE HTTP request.
  /// Shows cached snapshot immediately if available.
  Future<void> loadMonth(int year, int month, {bool silent = false}) async {
    final monthChanged = year != _selectedYear || month != _selectedMonth;
    _selectedYear = year;
    _selectedMonth = month;

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

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
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
      unawaited(refreshCounts());

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
    if (_hasMore) unawaited(loadAll());
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

  Future<void> reload() => loadMonth(_selectedYear, _selectedMonth);

  void setTypeFilter(TransactionType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> add(AppTransaction tx) async {
    await _repo.insert(tx);
    await reload();
  }

  Future<void> update(AppTransaction tx) async {
    await _repo.update(tx);
    await reload();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    final removed = _transactions.where((t) => t.id == id).firstOrNull;
    _transactions.removeWhere((t) => t.id == id);
    if (removed != null) {
      if (removed.type == TransactionType.income) {
        _incomeCents = (_incomeCents - removed.amountCents).clamp(0, 1 << 62);
      } else {
        _expenseCents = (_expenseCents - removed.amountCents).clamp(0, 1 << 62);
      }
    }
    notifyListeners();
    unawaited(refreshCounts());
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
