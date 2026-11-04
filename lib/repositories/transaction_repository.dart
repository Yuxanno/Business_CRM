import '../models/transaction.dart';
import '../services/database_service.dart';

class TransactionRepository {
  final _db = DatabaseService.instance;

  Future<List<AppTransaction>> getAll() async {
    final db = await _db.database;
    final maps =
        await db.query('transactions', orderBy: 'date DESC');
    return maps.map(AppTransaction.fromMap).toList();
  }

  Future<List<AppTransaction>> getForMonth(int year, int month) async {
    final db = await _db.database;
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map(AppTransaction.fromMap).toList();
  }

  Future<List<AppTransaction>> getForDateRange(
      DateTime from, DateTime to) async {
    final db = await _db.database;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map(AppTransaction.fromMap).toList();
  }

  Future<List<AppTransaction>> getByType(TransactionType type) async {
    final db = await _db.database;
    final maps = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: [type.toStoredString()],
      orderBy: 'date DESC',
    );
    return maps.map(AppTransaction.fromMap).toList();
  }

  Future<List<AppTransaction>> search(String query) async {
    final db = await _db.database;
    final q = '%${query.toLowerCase()}%';
    final maps = await db.query(
      'transactions',
      where: 'LOWER(description) LIKE ? OR LOWER(category) LIKE ?',
      whereArgs: [q, q],
      orderBy: 'date DESC',
    );
    return maps.map(AppTransaction.fromMap).toList();
  }

  Future<void> insert(AppTransaction tx) async {
    final db = await _db.database;
    await db.insert('transactions', tx.toMap());
  }

  Future<void> update(AppTransaction tx) async {
    final db = await _db.database;
    await db.update(
      'transactions',
      tx.toMap(),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Sum of income for a given month (in cents).
  Future<int> getTotalIncomeCents(int year, int month) async {
    final db = await _db.database;
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amountCents), 0) as total
      FROM transactions
      WHERE type = 'income' AND date >= ? AND date < ?
    ''', [start, end]);
    return (result.first['total'] as int?) ?? 0;
  }

  /// Sum of expenses for a given month (in cents).
  Future<int> getTotalExpenseCents(int year, int month) async {
    final db = await _db.database;
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amountCents), 0) as total
      FROM transactions
      WHERE type = 'expense' AND date >= ? AND date < ?
    ''', [start, end]);
    return (result.first['total'] as int?) ?? 0;
  }

  /// Daily income + expense totals for a month (for charts).
  Future<List<Map<String, dynamic>>> getDailyTotals(
      int year, int month) async {
    final db = await _db.database;
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    return db.rawQuery('''
      SELECT 
        SUBSTR(date, 1, 10) as day,
        type,
        COALESCE(SUM(amountCents), 0) as total
      FROM transactions
      WHERE date >= ? AND date < ?
      GROUP BY day, type
      ORDER BY day ASC
    ''', [start, end]);
  }
}
