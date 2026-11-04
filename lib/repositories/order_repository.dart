import '../models/order.dart';
import '../services/database_service.dart';

class OrderRepository {
  final _db = DatabaseService.instance;

  Future<List<Order>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('orders', orderBy: 'createdAt DESC');
    return maps.map(Order.fromMap).toList();
  }

  Future<Order?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Order.fromMap(maps.first);
  }

  Future<List<Order>> getByCustomer(String customerId) async {
    final db = await _db.database;
    final maps = await db.query(
      'orders',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Order.fromMap).toList();
  }

  Future<List<Order>> getByStatus(OrderStatus status) async {
    final db = await _db.database;
    final maps = await db.query(
      'orders',
      where: 'status = ?',
      whereArgs: [status.toStoredString()],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Order.fromMap).toList();
  }

  Future<List<Order>> search(String query) async {
    final db = await _db.database;
    final q = '%${query.toLowerCase()}%';
    final maps = await db.query(
      'orders',
      where: 'LOWER(title) LIKE ? OR LOWER(customerName) LIKE ?',
      whereArgs: [q, q],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Order.fromMap).toList();
  }

  Future<void> insert(Order order) async {
    final db = await _db.database;
    await db.insert('orders', order.toMap());
  }

  Future<void> update(Order order) async {
    final db = await _db.database;
    await db.update(
      'orders',
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Order payments ────────────────────────────────────────────────────────

  Future<void> insertPayment(OrderPayment payment) async {
    final db = await _db.database;
    await db.insert('order_payments', payment.toMap());
  }

  Future<List<OrderPayment>> getPaymentsForOrder(String orderId) async {
    final db = await _db.database;
    final maps = await db.query(
      'order_payments',
      where: 'orderId = ?',
      whereArgs: [orderId],
      orderBy: 'paidAt DESC',
    );
    return maps.map(OrderPayment.fromMap).toList();
  }

  Future<void> deletePayment(String paymentId) async {
    final db = await _db.database;
    await db.delete(
        'order_payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  /// Get active orders count.
  Future<int> getActiveCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM orders 
      WHERE status IN ('new', 'inProgress')
    ''');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Get total outstanding balance across all non-cancelled orders.
  Future<int> getTotalOutstandingCents() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT SUM(totalPriceCents - receivedCents) as total 
      FROM orders 
      WHERE status != 'cancelled' AND totalPriceCents > receivedCents
    ''');
    return (result.first['total'] as int?) ?? 0;
  }
}
