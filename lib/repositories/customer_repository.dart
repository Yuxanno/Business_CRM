import '../models/customer.dart';
import '../services/database_service.dart';

class CustomerRepository {
  final _db = DatabaseService.instance;

  Future<List<Customer>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('customers', orderBy: 'name ASC');
    return maps.map(Customer.fromMap).toList();
  }

  Future<Customer?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<void> insert(Customer customer) async {
    final db = await _db.database;
    await db.insert('customers', customer.toMap());
  }

  Future<void> update(Customer customer) async {
    final db = await _db.database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Customer>> search(String query) async {
    final db = await _db.database;
    final q = '%${query.toLowerCase()}%';
    final maps = await db.query(
      'customers',
      where: 'LOWER(name) LIKE ? OR phone LIKE ?',
      whereArgs: [q, q],
      orderBy: 'name ASC',
    );
    return maps.map(Customer.fromMap).toList();
  }

  /// Increment aggregated stats after a payment.
  Future<void> addPayment(String customerId, int amountCents) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE customers 
      SET totalReceivedCents = totalReceivedCents + ?
      WHERE id = ?
    ''', [amountCents, customerId]);
  }

  /// Called when an order is created for a customer.
  Future<void> addOrder(String customerId, int orderAmountCents) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE customers 
      SET totalOrdersAmountCents = totalOrdersAmountCents + ?,
          totalOrdersCount = totalOrdersCount + 1
      WHERE id = ?
    ''', [orderAmountCents, customerId]);
  }

  /// Called when an order is cancelled/deleted to rollback stats.
  Future<void> removeOrder(
      String customerId, int orderAmountCents, int receivedCents) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE customers 
      SET totalOrdersAmountCents = MAX(0, totalOrdersAmountCents - ?),
          totalReceivedCents = MAX(0, totalReceivedCents - ?),
          totalOrdersCount = MAX(0, totalOrdersCount - 1)
      WHERE id = ?
    ''', [orderAmountCents, receivedCents, customerId]);
  }
}
