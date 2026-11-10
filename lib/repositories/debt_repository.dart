import '../models/debt.dart';
import '../services/api_client.dart';

class DebtRepository {
  final _api = ApiClient.instance;

  List<Debt> _parse(dynamic json) {
    final items = (json['items'] as List?) ?? const [];
    return items
        .map((e) => Debt.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Debt>> getAll() async => _parse(await _api.get('/api/debts?limit=300'));

  Future<List<Debt>> getByDirection(DebtDirection direction) async => _parse(
        await _api.get('/api/debts?direction=${direction.toStoredString()}'),
      );

  Future<Debt?> getById(String id) async {
    try {
      final json = await _api.get('/api/debts/$id');
      return Debt.fromMap(Map<String, dynamic>.from(json as Map));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> insert(Debt debt) async {
    await _api.post('/api/debts', debt.toMap());
  }

  Future<void> update(Debt debt) async {
    await _api.put('/api/debts/${debt.id}', debt.toMap());
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/debts/$id');
  }

  Future<void> insertPayment(DebtPayment payment) async {
    await _api.post('/api/debts/${payment.debtId}/payments', {
      'amountCents': payment.amountCents,
      'paidAt': payment.paidAt.toIso8601String(),
      'notes': payment.notes,
      'paymentId': payment.id,
      'transactionId': payment.transactionId,
    });
  }

  Future<List<DebtPayment>> getPaymentsForDebt(String debtId) async {
    final json = await _api.get('/api/debts/$debtId/payments');
    final items = (json['items'] as List?) ?? const [];
    return items
        .map((e) => DebtPayment.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> deletePayment(String paymentId) async {}

  Future<int> getTotalReceivableCents() async {
    final json = await _api.get('/api/dashboard');
    return (json['receivableCents'] as num?)?.toInt() ?? 0;
  }

  Future<int> getTotalPayableCents() async {
    final json = await _api.get('/api/dashboard');
    return (json['payableCents'] as num?)?.toInt() ?? 0;
  }
}
