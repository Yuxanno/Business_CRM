import '../models/order.dart';
import '../services/api_client.dart';

class OrderPage {
  const OrderPage({required this.items, required this.hasMore});

  final List<Order> items;
  final bool hasMore;
}

class OrderRepository {
  final _api = ApiClient.instance;

  List<Order> _parse(dynamic json) {
    final items = (json['items'] as List?) ?? const [];
    return items
        .map((e) => Order.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<OrderPage> getPage({
    int skip = 0,
    int limit = 25,
    OrderStatus? status,
    String? query,
  }) async {
    final params = <String>['skip=$skip', 'limit=$limit'];
    if (status != null) params.add('status=${status.toStoredString()}');
    if (query != null && query.trim().isNotEmpty) {
      params.add('q=${Uri.encodeQueryComponent(query.trim())}');
    }
    final json = await _api.get('/api/orders?${params.join('&')}');
    return OrderPage(
      items: _parse(json),
      hasMore: json['hasMore'] == true,
    );
  }

  Future<List<Order>> getAll() async =>
      _parse(await _api.get('/api/orders?limit=300'));

  Future<Order?> getById(String id) async {
    try {
      final json = await _api.get('/api/orders/$id');
      return Order.fromMap(Map<String, dynamic>.from(json as Map));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Order>> getByCustomer(String customerId) async =>
      _parse(await _api.get('/api/orders?customerId=$customerId&limit=200'));

  Future<List<Order>> getByStatus(OrderStatus status) async => _parse(
        await _api.get('/api/orders?status=${status.toStoredString()}'),
      );

  Future<List<Order>> search(String query) async => _parse(
        await _api.get('/api/orders?q=${Uri.encodeQueryComponent(query)}'),
      );

  Future<void> insert(Order order) async {
    await _api.post('/api/orders', order.toMap());
  }

  Future<void> update(Order order) async {
    await _api.put('/api/orders/${order.id}', order.toMap());
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/orders/$id');
  }

  Future<void> insertPayment(OrderPayment payment) async {
    await _api.post('/api/orders/${payment.orderId}/payments', {
      'amountCents': payment.amountCents,
      'paidAt': payment.paidAt.toIso8601String(),
      'notes': payment.notes,
      'paymentId': payment.id,
      'transactionId': payment.transactionId,
    });
  }

  Future<List<OrderPayment>> getPaymentsForOrder(String orderId) async {
    final json = await _api.get('/api/orders/$orderId/payments');
    final items = (json['items'] as List?) ?? const [];
    return items
        .map((e) => OrderPayment.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> deletePayment(String paymentId) async {}

  Future<int> getActiveCount() async {
    final json = await _api.get('/api/dashboard/summary');
    return (json['activeOrdersCount'] as num?)?.toInt() ?? 0;
  }

  Future<int> getTotalOutstandingCents() async {
    final orders = await getAll();
    return orders
        .where((o) => o.status != OrderStatus.cancelled && o.remainingCents > 0)
        .fold<int>(0, (sum, o) => sum + o.remainingCents);
  }

  /// Real totals per status from the server (not limited by pagination).
  Future<Map<String, dynamic>> getCounts() async =>
      Map<String, dynamic>.from(await _api.get('/api/orders/counts') as Map);
}
