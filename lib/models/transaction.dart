import '../l10n/app_tr.dart';

/// Transaction types.
enum TransactionType {
  income,
  expense;

  static TransactionType fromString(String v) =>
      v == 'expense' ? TransactionType.expense : TransactionType.income;

  String toStoredString() => name; // 'income' | 'expense'
}

/// A financial transaction.
/// All monetary values stored as integer cents to avoid floating-point errors.
class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.amountCents,
    required this.type,
    required this.date,
    required this.createdAt,
    this.category,
    this.description,
    this.customerId,
    this.orderId,
    this.debtId,
    this.paymentMethod,
    this.notes,
    this.linkedEntityType, // 'order_payment' | 'debt_payment' | 'manual'
    this.linkedEntityId,
  });

  final String id;
  final int amountCents;
  final TransactionType type;
  final String? category;
  final String? description;
  final DateTime date;
  final DateTime createdAt;
  final String? customerId;
  final String? orderId;
  final String? debtId;
  final String? paymentMethod;
  final String? notes;
  final String? linkedEntityType;
  final String? linkedEntityId;

  AppTransaction copyWith({
    String? id,
    int? amountCents,
    TransactionType? type,
    String? category,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    String? customerId,
    String? orderId,
    String? debtId,
    String? paymentMethod,
    String? notes,
    String? linkedEntityType,
    String? linkedEntityId,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      amountCents: amountCents ?? this.amountCents,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      customerId: customerId ?? this.customerId,
      orderId: orderId ?? this.orderId,
      debtId: debtId ?? this.debtId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      linkedEntityType: linkedEntityType ?? this.linkedEntityType,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amountCents': amountCents,
        'type': type.toStoredString(),
        'category': category,
        'description': description,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'customerId': customerId,
        'orderId': orderId,
        'debtId': debtId,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'linkedEntityType': linkedEntityType,
        'linkedEntityId': linkedEntityId,
      };

  factory AppTransaction.fromMap(Map<String, dynamic> map) => AppTransaction(
        id: map['id'] as String,
        amountCents: (map['amountCents'] as num).toInt(),
        type: TransactionType.fromString(map['type'] as String),
        category: map['category'] as String?,
        description: map['description'] as String?,
        date: DateTime.parse(map['date'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String),
        customerId: map['customerId'] as String?,
        orderId: map['orderId'] as String?,
        debtId: map['debtId'] as String?,
        paymentMethod: map['paymentMethod'] as String?,
        notes: map['notes'] as String?,
        linkedEntityType: map['linkedEntityType'] as String?,
        linkedEntityId: map['linkedEntityId'] as String?,
      );
}

/// Default transaction categories and label helper.
class TransactionCategories {
  TransactionCategories._();

  static const List<String> income = [
    'order_payment',
    'service',
    'sale',
    'refund_received',
    'other_income',
  ];

  static const List<String> expense = [
    'supplies',
    'rent',
    'utilities',
    'transport',
    'marketing',
    'salary',
    'equipment',
    'other_expense',
  ];

  static const Map<String, String> defaultLabels = {
    'order_payment': 'Оплата заказа',
    'service': 'Услуга',
    'sale': 'Продажа',
    'refund_received': 'Возврат',
    'other_income': 'Прочее',
    'supplies': 'Материалы',
    'rent': 'Аренда',
    'utilities': 'Коммуналка',
    'transport': 'Транспорт',
    'marketing': 'Маркетинг',
    'salary': 'Зарплата',
    'equipment': 'Оборудование',
    'taxes': 'Налоги',
    'other_expense': 'Прочее',
    'debt_received': 'Возврат долга',
    'debt_paid': 'Выплата долга',
    'other': 'Другое',
  };

  static const Map<String, String> defaultLabelsEn = {
    'order_payment': 'Order payment',
    'service': 'Service',
    'sale': 'Sale',
    'refund_received': 'Refund',
    'other_income': 'Other',
    'supplies': 'Supplies',
    'rent': 'Rent',
    'utilities': 'Utilities',
    'transport': 'Transport',
    'marketing': 'Marketing',
    'salary': 'Salary',
    'equipment': 'Equipment',
    'taxes': 'Taxes',
    'other_expense': 'Other',
    'debt_received': 'Debt repayment',
    'debt_paid': 'Debt payment',
    'other': 'Other',
  };

  static final Map<String, String> customLabels = {};

  static String labelFor(String key) =>
      customLabels[key] ??
      (AppTr.isEn ? defaultLabelsEn[key] : defaultLabels[key]) ??
      key;
}
