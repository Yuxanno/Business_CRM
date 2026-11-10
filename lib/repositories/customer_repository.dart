import '../models/customer.dart';
import '../services/api_client.dart';

class CustomerRepository {
  final _api = ApiClient.instance;

  Future<List<Customer>> getAll() async {
    final json = await _api.get('/api/customers?limit=300');
    final items = (json['items'] as List?) ?? const [];
    return items
        .map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

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

  Future<List<Customer>> search(String query) async {
    final json = await _api.get('/api/customers?q=${Uri.encodeQueryComponent(query)}');
    final items = (json['items'] as List?) ?? const [];
    return items
        .map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Aggregates are updated by the API when orders/payments change.
  Future<void> addPayment(String customerId, int amountCents) async {}

  Future<void> addOrder(String customerId, int orderAmountCents) async {}

  Future<void> removeOrder(
      String customerId, int orderAmountCents, int receivedCents) async {}
}
