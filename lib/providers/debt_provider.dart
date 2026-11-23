import 'dart:async';
import 'package:flutter/material.dart';
import '../models/debt.dart';
import '../repositories/debt_repository.dart';
import '../services/local_cache.dart';
import '../services/notification_service.dart';
import '../services/sync_queue.dart';

class DebtProvider extends ChangeNotifier {
  static const int pageSize = 20;
  static const _cacheKey = 'debts_page1';

  final _repo = DebtRepository();

  List<Debt> _debts = [];
  DebtDirection _selectedDirection = DebtDirection.receivable;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _hasLoadedOnce = false;
  DateTime? _lastFetchedAt;
  String? _error;

  DebtDirection get selectedDirection => _selectedDirection;

  void setSelectedDirection(DebtDirection direction) {
    if (_selectedDirection == direction) return;
    _selectedDirection = direction;
    notifyListeners();
  }

  List<Debt> get receivables =>
      _debts.where((d) => d.direction == DebtDirection.receivable).toList();

  List<Debt> get payables =>
      _debts.where((d) => d.direction == DebtDirection.payable).toList();

  List<Debt> get all => _debts;

  /// Returns all debts linked to [customerId] or matching [customerName] (case-insensitive).
  List<Debt> debtsForCustomer(String customerId, String customerName) {
    final normName = customerName.trim().toLowerCase();
    return _debts.where((d) {
      if (d.customerId != null && d.customerId == customerId) return true;
      return normName.isNotEmpty &&
          d.personName.trim().toLowerCase() == normName;
    }).toList();
  }

  /// Returns total unpaid receivable debt (in cents) for a customer.
  int remainingDebtForCustomer(String customerId, String customerName) {
    return debtsForCustomer(customerId, customerName)
        .where((d) => d.direction == DebtDirection.receivable && !d.isFullyPaid)
        .fold<int>(0, (sum, d) => sum + d.remainingCents);
  }

  bool get isLoading => _isLoading && _debts.isEmpty;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  /// Real totals reported by the server (independent of how many pages are loaded).
  Map<String, dynamic>? _counts;
  Map<String, dynamic>? get counts => _counts;
  int countFor(DebtDirection direction, String key) {
    final d = _counts?[direction == DebtDirection.receivable ? 'receivable' : 'payable'];
    if (d is Map && d[key] is num) return (d[key] as num).toInt();
    return -1;
  }
  int get totalCount => (_counts?['total'] as num?)?.toInt() ?? _debts.length;

  Future<void> hydrateFromCache() async {
    if (_hasLoadedOnce && _debts.isNotEmpty) return;
    final results = await Future.wait([
      LocalCache.readMap('${_cacheKey}_counts'),
      LocalCache.readMap(_cacheKey),
    ]);
    _counts ??= results[0];
    final cached = results[1];
    if (cached != null) {
      final rawItems = (cached['items'] as List?) ?? const [];
      _debts = rawItems
          .map((e) => Debt.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _hasMore = cached['hasMore'] == true;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  void applyBootstrapPayload(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    _debts = rawItems
        .map((e) => Debt.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    _hasMore = json['hasMore'] == true;
    _hasLoadedOnce = true;
    _isLoading = false;
    _lastFetchedAt = DateTime.now();

    final rawCounts = json['counts'];
    if (rawCounts is Map) {
      _counts = Map<String, dynamic>.from(rawCounts);
      unawaited(LocalCache.writeMap('${_cacheKey}_counts', _counts!));
    }
    notifyListeners();
    unawaited(LocalCache.writeMap(_cacheKey, {
      'items': _debts.map((d) => d.toMap()).toList(),
      'hasMore': _hasMore,
    }));
  }

  Future<void> load({bool silent = false, bool force = false}) async {
    if (!force &&
        _hasLoadedOnce &&
        _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!) <
            const Duration(seconds: 20)) {
      return;
    }

    if (_debts.isEmpty) {
      _counts ??= await LocalCache.readMap('${_cacheKey}_counts');
      final cached = await LocalCache.readMap(_cacheKey);
      if (cached != null) {
        final rawItems = (cached['items'] as List?) ?? const [];
        _debts = rawItems
            .map((e) => Debt.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _hasMore = cached['hasMore'] == true;
        notifyListeners();
      }
    }

    if (_isLoading) return;
    if (!silent && _debts.isEmpty) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    } else {
      _isLoading = true;
      _error = null;
    }

    try {
      final page = await _repo.getPage(skip: 0, limit: pageSize);
      _debts = page.items;
      _hasMore = page.hasMore;
      _hasLoadedOnce = true;
      _lastFetchedAt = DateTime.now();
      unawaited(refreshCounts());

      unawaited(LocalCache.writeMap(_cacheKey, {
        'items': _debts.map((d) => d.toMap()).toList(),
        'hasMore': _hasMore,
      }));
      unawaited(NotificationService.instance.updateDebts(_debts));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes real totals from the server.
  Future<void> refreshCounts() async {
    try {
      _counts = await _repo.getCounts();
      unawaited(LocalCache.writeMap('${_cacheKey}_counts', _counts!));
      notifyListeners();
    } catch (_) {}
  }

  /// Loads the remaining pages in the background so lists, filters and
  /// counters always reflect everything that really exists.
  Future<void> loadAll({int maxPages = 40}) async {
    var guard = 0;
    while (_hasMore && guard++ < maxPages) {
      if (_isLoadingMore) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        continue;
      }
      final before = _debts.length;
      await loadMore();
      if (_debts.length == before) break;
    }
  }

  Future<void> prefetchIfNeeded() async {
    if (_hasLoadedOnce || _isLoading) return;
    await load(silent: true);
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _repo.getPage(
        skip: _debts.length,
        limit: pageSize,
      );
      final existingIds = _debts.map((d) => d.id).toSet();
      final fresh = page.items.where((d) => !existingIds.contains(d.id));
      _debts = [..._debts, ...fresh];
      _hasMore = page.hasMore;
    } catch (_) {
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<Debt?> getById(String id) async {
    try {
      return await _repo.getById(id);
    } catch (_) {
      return _debts.where((d) => d.id == id).firstOrNull;
    }
  }

  // ── Optimistic writes: UI updates in the same frame, server sync in background.

  void _persistSnapshot() {
    unawaited(LocalCache.writeMap(_cacheKey, {
      'items': _debts.map((d) => d.toMap()).toList(),
      'hasMore': _hasMore,
    }));
    unawaited(NotificationService.instance.updateDebts(_debts));
  }

  void _restore(List<Debt> snapshot) {
    _debts = snapshot;
    notifyListeners();
    _persistSnapshot();
  }

  Future<void> add(Debt debt) async {
    final before = List<Debt>.of(_debts);
    _debts = [debt, ..._debts];
    notifyListeners();
    _persistSnapshot();
    SyncQueue.background(
      () => _repo.insert(debt),
      onError: (_) => _restore(before),
      onSuccess: () => load(silent: true, force: true),
    );
  }

  Future<void> update(Debt debt) async {
    final before = List<Debt>.of(_debts);
    final idx = _debts.indexWhere((d) => d.id == debt.id);
    if (idx != -1) {
      _debts = List<Debt>.of(_debts)..[idx] = debt;
      notifyListeners();
      _persistSnapshot();
    }
    SyncQueue.background(
      () => _repo.update(debt),
      onError: (_) => _restore(before),
      onSuccess: refreshCounts,
    );
  }

  Future<void> delete(String id) async {
    final before = List<Debt>.of(_debts);
    _debts = _debts.where((d) => d.id != id).toList();
    notifyListeners();
    _persistSnapshot();
    SyncQueue.background(
      () => _repo.delete(id),
      onError: (_) => _restore(before),
      onSuccess: refreshCounts,
    );
  }

  Future<void> recordPayment({
    required String debtId,
    required int amountCents,
    required String paymentId,
    required String transactionId,
    DateTime? paidAt,
    String? notes,
  }) async {
    final debt = _debts.where((d) => d.id == debtId).firstOrNull;
    if (debt == null) return;
    final now = paidAt ?? DateTime.now();

    final clamped = amountCents.clamp(0, debt.remainingCents);
    if (clamped <= 0) return;

    final newPaid = debt.paidAmountCents + clamped;
    final updatedDebt = debt.copyWith(
      paidAmountCents: newPaid,
      status: _computeStatus(debt.copyWith(paidAmountCents: newPaid)),
      updatedAt: now,
    );

    final before = List<Debt>.of(_debts);
    final idx = _debts.indexWhere((d) => d.id == debtId);
    if (idx != -1) {
      _debts = List<Debt>.of(_debts)..[idx] = updatedDebt;
      notifyListeners();
      _persistSnapshot();
    }

    SyncQueue.background(
      () => _repo.insertPayment(DebtPayment(
        id: paymentId,
        debtId: debtId,
        amountCents: clamped,
        paidAt: now,
        notes: notes,
        transactionId: transactionId,
      )),
      onError: (_) => _restore(before),
      onSuccess: () async {
        final fresh = await _repo.getById(debtId);
        final i = _debts.indexWhere((d) => d.id == debtId);
        if (fresh != null && i != -1) {
          _debts = List<Debt>.of(_debts)..[i] = fresh;
          notifyListeners();
          _persistSnapshot();
        }
        unawaited(refreshCounts());
      },
    );
  }

  Future<List<DebtPayment>> getPaymentsForDebt(String debtId) =>
      _repo.getPaymentsForDebt(debtId);

  Future<int> getTotalReceivableCents() => _repo.getTotalReceivableCents();
  Future<int> getTotalPayableCents() => _repo.getTotalPayableCents();

  DebtStatus _computeStatus(Debt debt) {
    if (debt.paidAmountCents >= debt.originalAmountCents) {
      return DebtStatus.paid;
    }
    if (debt.paidAmountCents > 0) {
      if (debt.dueDate != null && DateTime.now().isAfter(debt.dueDate!)) {
        return DebtStatus.overdue;
      }
      return DebtStatus.partiallyPaid;
    }
    if (debt.dueDate != null && DateTime.now().isAfter(debt.dueDate!)) {
      return DebtStatus.overdue;
    }
    return DebtStatus.unpaid;
  }
}
