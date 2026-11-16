import '../models/customer.dart';
import '../services/api_client.dart';

class CustomerPage {
  const CustomerPage({required this.items, required this.hasMore});

  final List<Customer> items;
  final bool hasMore;
}

class CustomerRepository {
  final _api = ApiClient.instance;

  List<Customer> _parse(dynamic json) {
    final items = (json['items'] as List?) ?? const [];
    return items
        .map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CustomerPage> getPage({
    int skip = 0,
    int limit = 25,
    String? query,
  }) async {
    final params = <String>['skip=$skip', 'limit=$limit'];
    if (query != null && query.trim().isNotEmpty) {
      params.add('q=${Uri.encodeQueryComponent(query.trim())}');
    }
    final json = await _api.get('/api/customers?${params.join('&')}');
    return CustomerPage(
      items: _parse(json),
      hasMore: json['hasMore'] == true,
    );
  }

  Future<List<Customer>> getAll() async =>
      _parse(await _api.get('/api/customers?limit=300'));

  Future<Customer?> getById(String id) async {
    try {
      final json = await _api.get('/api/customers/$id');
      return Customer.fromMap(Map<String, dynamic>.from(json as Map));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> insert(Customer customer) async {
    await _api.post('/api/customers', customer.toMap());
  }

  Future<void> update(Customer customer) async {
    await _api.put('/api/customers/${customer.id}', customer.toMap());
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/customers/$id');
  }

  Future<List<Customer>> search(String query) async => _parse(
        await _api.get('/api/customers?q=${Uri.encodeQueryComponent(query)}'),
      );

  /// Aggregates are updated by the API when orders/payments change.
  Future<void> addPayment(String customerId, int amountCents) async {}

  Future<void> addOrder(String customerId, int orderAmountCents) async {}

  Future<void> removeOrder(
      String customerId, int orderAmountCents, int receivedCents) async {}

  /// Real totals from the server (not limited by pagination).
  Future<Map<String, dynamic>> getCounts() async =>
      Map<String, dynamic>.from(await _api.get('/api/customers/counts') as Map);
}
