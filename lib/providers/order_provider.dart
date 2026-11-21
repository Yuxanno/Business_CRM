import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../repositories/order_repository.dart';
import '../services/local_cache.dart';
import '../services/notification_service.dart';

class OrderProvider extends ChangeNotifier {
  static const int pageSize = 50;
  static const _cacheKey = 'orders_page1';

  final _orderRepo = OrderRepository();

  List<Order> _orders = [];
  OrderStatus? _statusFilter;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _hasLoadedOnce = false;
  DateTime? _lastFetchedAt;
  String? _error;

  List<Order> get allOrders => _orders;

  List<Order> get orders {
    var list = _orders;
    if (_statusFilter != null) {
      list = list.where((o) => o.status == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((o) =>
              o.title.toLowerCase().contains(q) ||
              o.customerName.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  bool get isLoading => _isLoading && _orders.isEmpty;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  /// Real totals reported by the server (independent of how many pages are loaded).
  Map<String, dynamic>? _counts;
  Map<String, dynamic>? get counts => _counts;
  int get totalCount => (_counts?['total'] as num?)?.toInt() ?? _orders.length;
  int countForStatus(OrderStatus s) {
    final m = _counts?['byStatus'];
    if (m is Map && m[s.toStoredString()] is num) return (m[s.toStoredString()] as num).toInt();
    return _orders.where((o) => o.status == s).length;
  }
  OrderStatus? get statusFilter => _statusFilter;

  /// Computes unpaid balance for a customer across active (non-cancelled) orders
  /// when orders are loaded in memory. Returns null if orders aren't loaded yet.
  int? orderDebtForCustomer(String customerId) {
    if (!_hasLoadedOnce && _orders.isEmpty) return null;
    final customerOrders = _orders.where((o) => o.customerId == customerId);
    if (customerOrders.isEmpty && _hasMore) return null;
    var debt = 0;
    for (final o in customerOrders) {
      if (o.status != OrderStatus.cancelled && o.remainingCents > 0) {
        debt += o.remainingCents;
      }
    }
    return debt;
  }

  Future<void> hydrateFromCache() async {
    _counts ??= await LocalCache.readMap('${_cacheKey}_counts');
    final cached = await LocalCache.readMap(_cacheKey);
    if (cached != null) {
      final rawItems = (cached['items'] as List?) ?? const [];
      _orders = rawItems
          .map((e) => Order.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _hasMore = cached['hasMore'] == true;
      _hasLoadedOnce = true;
    }
  }

  void applyBootstrapPayload(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    _orders = rawItems
        .map((e) => Order.fromMap(Map<String, dynamic>.from(e as Map)))
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
      'items': _orders.map((o) => o.toMap()).toList(),
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

    if (_orders.isEmpty) {
      _counts ??= await LocalCache.readMap('${_cacheKey}_counts');
      final cached = await LocalCache.readMap(_cacheKey);
      if (cached != null) {
        final rawItems = (cached['items'] as List?) ?? const [];
        _orders = rawItems
            .map((e) => Order.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _hasMore = cached['hasMore'] == true;
        notifyListeners();
      }
    }

    if (_isLoading) return;
    if (!silent && _orders.isEmpty) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    } else {
      _isLoading = true;
      _error = null;
    }

    try {
      final page = await _orderRepo.getPage(skip: 0, limit: pageSize);
      _orders = page.items;
      _hasMore = page.hasMore;
      _hasLoadedOnce = true;
      _lastFetchedAt = DateTime.now();
      unawaited(refreshCounts());

      unawaited(LocalCache.writeMap(_cacheKey, {
        'items': _orders.map((o) => o.toMap()).toList(),
        'hasMore': _hasMore,
      }));
      unawaited(NotificationService.instance.updateOrders(_orders));
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
      _counts = await _orderRepo.getCounts();
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
      final before = _orders.length;
      await loadMore();
      if (_orders.length == before) break;
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _orderRepo.getPage(
        skip: _orders.length,
        limit: pageSize,
      );
      final existingIds = _orders.map((o) => o.id).toSet();
      final fresh = page.items.where((o) => !existingIds.contains(o.id));
      _orders = [..._orders, ...fresh];
      _hasMore = page.hasMore;
    } catch (_) {
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> prefetchIfNeeded() async {
    if (_hasLoadedOnce || _isLoading) return;
    await load(silent: true);
  }

  void setStatusFilter(OrderStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
    if (query.trim().isNotEmpty && _hasMore) {
      unawaited(loadAll());
    }
  }

  Future<Order?> getById(String id) => _orderRepo.getById(id);

  Future<List<Order>> getByCustomer(String customerId) =>
      _orderRepo.getByCustomer(customerId);

  Future<void> add(Order order) async {
    await _orderRepo.insert(order);
    _orders = [order, ..._orders];
    notifyListeners();
    unawaited(NotificationService.instance.updateOrders(_orders));
    unawaited(load(silent: true, force: true));
  }

  Future<void> update(Order order) async {
    await _orderRepo.update(order);
    final idx = _orders.indexWhere((o) => o.id == order.id);
    if (idx != -1) {
      _orders[idx] = order;
      notifyListeners();
      unawaited(NotificationService.instance.updateOrders(_orders));
    }
    unawaited(refreshCounts());
  }

  Future<void> delete(String id) async {
    await _orderRepo.delete(id);
    _orders.removeWhere((o) => o.id == id);
    notifyListeners();
    unawaited(NotificationService.instance.updateOrders(_orders));
    unawaited(refreshCounts());
  }

  Future<void> recordPayment({
    required String orderId,
    required String customerId,
    required int amountCents,
    required String paymentId,
    required String transactionId,
    DateTime? paidAt,
    String? notes,
  }) async {
    final now = paidAt ?? DateTime.now();
    await _orderRepo.insertPayment(OrderPayment(
      id: paymentId,
      orderId: orderId,
      customerId: customerId,
      amountCents: amountCents,
      paidAt: now,
      notes: notes,
      transactionId: transactionId,
    ));

    final updated = await _orderRepo.getById(orderId);
    if (updated != null) {
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        _orders[idx] = updated;
      } else {
        _orders.insert(0, updated);
      }
      notifyListeners();
      unawaited(NotificationService.instance.updateOrders(_orders));
    }
    unawaited(refreshCounts());
  }

  Future<List<OrderPayment>> getPaymentsForOrder(String orderId) =>
      _orderRepo.getPaymentsForOrder(orderId);

  Future<int> getActiveCount() => _orderRepo.getActiveCount();
}
