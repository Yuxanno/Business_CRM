import 'package:flutter/material.dart';
import '../models/order.dart';
import '../repositories/order_repository.dart';
import '../repositories/customer_repository.dart';

class OrderProvider extends ChangeNotifier {
  final _orderRepo = OrderRepository();
  final _customerRepo = CustomerRepository();

  List<Order> _orders = [];
  OrderStatus? _statusFilter;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

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

  bool get isLoading => _isLoading;
  String? get error => _error;
  OrderStatus? get statusFilter => _statusFilter;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _orderRepo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setStatusFilter(OrderStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<Order?> getById(String id) => _orderRepo.getById(id);

  Future<List<Order>> getByCustomer(String customerId) =>
      _orderRepo.getByCustomer(customerId);

  Future<void> add(Order order) async {
    await _orderRepo.insert(order);
    // Update customer aggregate stats
    await _customerRepo.addOrder(order.customerId, order.totalPriceCents);
    await load();
  }

  Future<void> update(Order order) async {
    await _orderRepo.update(order);
    final idx = _orders.indexWhere((o) => o.id == order.id);
    if (idx != -1) {
      _orders[idx] = order;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    final order = _orders.firstWhere((o) => o.id == id,
        orElse: () => throw Exception('Order not found'));
    await _orderRepo.delete(id);
    // Rollback customer stats
    await _customerRepo.removeOrder(
        order.customerId, order.totalPriceCents, order.receivedCents);
    _orders.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  /// Records a payment against an order.
  /// This is the core financial workflow:
  /// 1. Update order.receivedCents
  /// 2. Create an OrderPayment record
  /// 3. Create a linked Transaction (income)
  /// 4. Update customer.totalReceivedCents
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

    // Refresh local cache
    final updated = await _orderRepo.getById(orderId);
    if (updated != null) {
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        _orders[idx] = updated;
      } else {
        _orders.insert(0, updated);
      }
      notifyListeners();
    }
  }

  Future<List<OrderPayment>> getPaymentsForOrder(String orderId) =>
      _orderRepo.getPaymentsForOrder(orderId);

  Future<int> getActiveCount() => _orderRepo.getActiveCount();
}
