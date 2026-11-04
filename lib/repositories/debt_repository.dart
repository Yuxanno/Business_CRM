import '../models/debt.dart';
import '../services/database_service.dart';

class DebtRepository {
  final _db = DatabaseService.instance;

  Future<List<Debt>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('debts', orderBy: 'createdAt DESC');
    return maps.map(Debt.fromMap).toList();
  }

  Future<List<Debt>> getByDirection(DebtDirection direction) async {
    final db = await _db.database;
    final maps = await db.query(
      'debts',
      where: 'direction = ?',
      whereArgs: [direction.toStoredString()],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Debt.fromMap).toList();
  }

  Future<Debt?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query(
      'debts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Debt.fromMap(maps.first);
  }

  Future<void> insert(Debt debt) async {
    final db = await _db.database;
    await db.insert('debts', debt.toMap());
  }

  Future<void> update(Debt debt) async {
    final db = await _db.database;
    await db.update(
      'debts',
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Debt payments ─────────────────────────────────────────────────────────

  Future<void> insertPayment(DebtPayment payment) async {
    final db = await _db.database;
    await db.insert('debt_payments', payment.toMap());
  }

  Future<List<DebtPayment>> getPaymentsForDebt(String debtId) async {
    final db = await _db.database;
    final maps = await db.query(
      'debt_payments',
      where: 'debtId = ?',
      whereArgs: [debtId],
      orderBy: 'paidAt DESC',
    );
    return maps.map(DebtPayment.fromMap).toList();
  }

  Future<void> deletePayment(String paymentId) async {
    final db = await _db.database;
    await db.delete(
        'debt_payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  /// Total outstanding receivables (others owe me).
  Future<int> getTotalReceivableCents() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(originalAmountCents - paidAmountCents), 0) as total
      FROM debts
      WHERE direction = 'receivable' AND status != 'paid'
    ''');
    return (result.first['total'] as int?) ?? 0;
  }

  /// Total outstanding payables (I owe others).
  Future<int> getTotalPayableCents() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(originalAmountCents - paidAmountCents), 0) as total
      FROM debts
      WHERE direction = 'payable' AND status != 'paid'
    ''');
    return (result.first['total'] as int?) ?? 0;
  }
}
