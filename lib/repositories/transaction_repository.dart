import '../models/transaction.dart';
import '../services/api_client.dart';

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.hasMore,
    this.incomeCents,
    this.expenseCents,
  });

  final List<AppTransaction> items;
  final bool hasMore;
  final int? incomeCents;
  final int? expenseCents;
}

class TransactionRepository {
  final _api = ApiClient.instance;

  List<AppTransaction> _parse(dynamic json) {
    final items = (json['items'] as List?) ?? const [];
    return items
        .map((e) => AppTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AppTransaction>> getAll() async =>
      _parse(await _api.get('/api/transactions?limit=400'));

  Future<List<AppTransaction>> getForMonth(int year, int month) async {
    final start = DateTime(year, month).toUtc().toIso8601String();
    final end = DateTime(year, month + 1).toUtc().toIso8601String();
    return _parse(await _api.get(
      '/api/transactions?from=${Uri.encodeQueryComponent(start)}&to=${Uri.encodeQueryComponent(end)}&limit=400',
    ));
  }

  /// Fetches a single paginated slice ([limit] = 25 by default) for a month.
  /// When [includeSummary] is true and [skip] == 0, the server also returns
  /// monthly [incomeCents] and [expenseCents] in the same single HTTP call.
  Future<TransactionPage> getMonthPage(
    int year,
    int month, {
    int skip = 0,
    int limit = 25,
    bool includeSummary = false,
  }) async {
    final start = DateTime(year, month).toUtc().toIso8601String();
    final end = DateTime(year, month + 1).toUtc().toIso8601String();
    final summaryFlag = includeSummary && skip == 0 ? '&includeSummary=1' : '';
    final json = await _api.get(
      '/api/transactions?from=${Uri.encodeQueryComponent(start)}&to=${Uri.encodeQueryComponent(end)}&skip=$skip&limit=$limit$summaryFlag',
    );
    return TransactionPage(
      items: _parse(json),
      hasMore: json['hasMore'] == true,
      incomeCents: (json['incomeCents'] as num?)?.toInt(),
      expenseCents: (json['expenseCents'] as num?)?.toInt(),
    );
  }

  Future<List<AppTransaction>> getForDateRange(
      DateTime from, DateTime to) async {
    return _parse(await _api.get(
      '/api/transactions?from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}&to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}&limit=400',
    ));
  }

  Future<List<AppTransaction>> getByType(TransactionType type) async =>
      _parse(await _api.get('/api/transactions?type=${type.toStoredString()}'));

  Future<List<AppTransaction>> search(String query) async => _parse(
        await _api.get('/api/transactions?q=${Uri.encodeQueryComponent(query)}'),
      );

  Future<void> insert(AppTransaction tx) async {
    await _api.post('/api/transactions', tx.toMap());
  }

  Future<void> update(AppTransaction tx) async {
    await _api.put('/api/transactions/${tx.id}', tx.toMap());
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/transactions/$id');
  }

  Future<int> getTotalIncomeCents(int year, int month) async {
    final list = await getForMonth(year, month);
    return list
        .where((t) => t.type == TransactionType.income)
        .fold<int>(0, (s, t) => s + t.amountCents);
  }

  Future<int> getTotalExpenseCents(int year, int month) async {
    final list = await getForMonth(year, month);
    return list
        .where((t) => t.type == TransactionType.expense)
        .fold<int>(0, (s, t) => s + t.amountCents);
  }

  /// Single call — returns income and expense totals for a month.
  Future<({int incomeCents, int expenseCents})> getMonthSummary(
      int year, int month) async {
    final start = DateTime(year, month).toUtc().toIso8601String();
    final end = DateTime(year, month + 1).toUtc().toIso8601String();
    final json = await _api.get(
      '/api/transactions?from=${Uri.encodeQueryComponent(start)}&to=${Uri.encodeQueryComponent(end)}&limit=1&includeSummary=1',
    );
    return (
      incomeCents: (json['incomeCents'] as num?)?.toInt() ?? 0,
      expenseCents: (json['expenseCents'] as num?)?.toInt() ?? 0,
    );
  }

  /// Real income/expense/total operation counts for a month (not paginated).
  Future<({int total, int income, int expense})> getMonthCounts(
      int year, int month) async {
    final start = DateTime(year, month).toUtc().toIso8601String();
    final end = DateTime(year, month + 1).toUtc().toIso8601String();
    final json = await _api.get(
      '/api/transactions/counts?from=${Uri.encodeQueryComponent(start)}&to=${Uri.encodeQueryComponent(end)}',
    );
    return (
      total: (json['total'] as num?)?.toInt() ?? 0,
      income: (json['income'] as num?)?.toInt() ?? 0,
      expense: (json['expense'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> getDailyTotals(
      int year, int month) async {
    final json = await _api.get('/api/dashboard?year=$year&month=$month&tz=${DateTime.now().timeZoneOffset.inMinutes}');
    final rows = (json['chartData'] as List?) ?? const [];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
