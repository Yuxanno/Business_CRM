import 'dart:async';
import 'package:flutter/material.dart';
import '../models/debt.dart';
import '../repositories/debt_repository.dart';
import '../services/local_cache.dart';

class DebtProvider extends ChangeNotifier {
  static const int pageSize = 25;
  static const _cacheKey = 'debts_page1';

  final _repo = DebtRepository();

  List<Debt> _debts = [];
  DebtDirection _selectedDirection = DebtDirection.receivable;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _hasLoadedOnce = false;
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

  Future<void> load({bool silent = false}) async {
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

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final page = await _repo.getPage(skip: 0, limit: pageSize);
      _debts = page.items;
      _hasMore = page.hasMore;
      _hasLoadedOnce = true;
      unawaited(refreshCounts());

      unawaited(LocalCache.writeMap(_cacheKey, {
        'items': _debts.map((d) => d.toMap()).toList(),
        'hasMore': _hasMore,
      }));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    if (_hasMore) unawaited(loadAll());
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

  Future<Debt?> getById(String id) => _repo.getById(id);

  Future<void> add(Debt debt) async {
    await _repo.insert(debt);
    await load();
  }

  Future<void> update(Debt debt) async {
    await _repo.update(debt);
    final idx = _debts.indexWhere((d) => d.id == debt.id);
    if (idx != -1) {
      _debts[idx] = debt;
      notifyListeners();
    }
    unawaited(refreshCounts());
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _debts.removeWhere((d) => d.id == id);
    notifyListeners();
    unawaited(refreshCounts());
  }

  Future<void> recordPayment({
    required String debtId,
    required int amountCents,
    required String paymentId,
    required String transactionId,
    DateTime? paidAt,
    String? notes,
  }) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    final now = paidAt ?? DateTime.now();

    final clamped = amountCents.clamp(0, debt.remainingCents);
    if (clamped <= 0) return;

    final newPaid = debt.paidAmountCents + clamped;
    final updatedDebt = debt.copyWith(
      paidAmountCents: newPaid,
      status: _computeStatus(debt.copyWith(paidAmountCents: newPaid)),
      updatedAt: now,
    );

    await _repo.insertPayment(DebtPayment(
      id: paymentId,
      debtId: debtId,
      amountCents: clamped,
      paidAt: now,
      notes: notes,
      transactionId: transactionId,
    ));
    final fresh = await _repo.getById(debtId);

    final idx = _debts.indexWhere((d) => d.id == debtId);
    if (idx != -1) {
      _debts[idx] = fresh ?? updatedDebt;
      notifyListeners();
    }
    unawaited(refreshCounts());
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
