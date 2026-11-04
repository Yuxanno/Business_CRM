import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Manages the SQLite database lifecycle.
/// Call [DatabaseService.instance] to get the singleton.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  static const int _version = 1;
  static const String _dbName = 'business_manager.db';

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Enable foreign keys for referential integrity.
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        totalOrdersAmountCents INTEGER NOT NULL DEFAULT 0,
        totalReceivedCents INTEGER NOT NULL DEFAULT 0,
        totalOrdersCount INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        customerId TEXT NOT NULL,
        customerName TEXT NOT NULL,
        description TEXT,
        notes TEXT,
        totalPriceCents INTEGER NOT NULL,
        receivedCents INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'new',
        createdAt TEXT NOT NULL,
        dueDate TEXT,
        updatedAt TEXT,
        FOREIGN KEY (customerId) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE order_payments (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        customerId TEXT NOT NULL,
        amountCents INTEGER NOT NULL,
        paidAt TEXT NOT NULL,
        notes TEXT,
        transactionId TEXT,
        FOREIGN KEY (orderId) REFERENCES orders(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amountCents INTEGER NOT NULL,
        type TEXT NOT NULL,
        category TEXT,
        description TEXT,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        customerId TEXT,
        orderId TEXT,
        debtId TEXT,
        paymentMethod TEXT,
        notes TEXT,
        linkedEntityType TEXT,
        linkedEntityId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        personName TEXT NOT NULL,
        customerId TEXT,
        direction TEXT NOT NULL,
        originalAmountCents INTEGER NOT NULL,
        paidAmountCents INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'unpaid',
        description TEXT,
        createdAt TEXT NOT NULL,
        dueDate TEXT,
        notes TEXT,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE debt_payments (
        id TEXT PRIMARY KEY,
        debtId TEXT NOT NULL,
        amountCents INTEGER NOT NULL,
        paidAt TEXT NOT NULL,
        notes TEXT,
        transactionId TEXT,
        FOREIGN KEY (debtId) REFERENCES debts(id)
      )
    ''');

    // Indexes for frequent queries
    await db.execute(
        'CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute(
        'CREATE INDEX idx_orders_customerId ON orders(customerId)');
    await db.execute(
        'CREATE INDEX idx_order_payments_orderId ON order_payments(orderId)');
    await db.execute(
        'CREATE INDEX idx_debt_payments_debtId ON debt_payments(debtId)');
    await db.execute(
        'CREATE INDEX idx_debts_direction ON debts(direction)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here.
  }

  /// Close the database (mostly for testing).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
