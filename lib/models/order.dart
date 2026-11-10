/// Order statuses.
enum OrderStatus {
  newOrder,
  inProgress,
  completed,
  cancelled;

  String get labelKey => switch (this) {
        OrderStatus.newOrder => 'status_new',
        OrderStatus.inProgress => 'status_in_progress',
        OrderStatus.completed => 'status_completed',
        OrderStatus.cancelled => 'status_cancelled',
      };

  static OrderStatus fromString(String value) => switch (value) {
        'inProgress' => OrderStatus.inProgress,
        'completed' => OrderStatus.completed,
        'cancelled' => OrderStatus.cancelled,
        _ => OrderStatus.newOrder,
      };

  String toStoredString() => switch (this) {
        OrderStatus.newOrder => 'new',
        OrderStatus.inProgress => 'inProgress',
        OrderStatus.completed => 'completed',
        OrderStatus.cancelled => 'cancelled',
      };
}

/// A business order.
/// totalPriceCents is the agreed price.
/// receivedCents is actual money received (via OrderPayments).
class Order {
  const Order({
    required this.id,
    required this.title,
    required this.customerId,
    required this.customerName,
    required this.totalPriceCents,
    required this.receivedCents,
    required this.status,
    required this.createdAt,
    this.description,
    this.notes,
    this.dueDate,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String customerId;
  final String customerName; // denormalized for quick display
  final String? description;
  final String? notes;
  final int totalPriceCents;
  final int receivedCents;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? updatedAt;

  int get remainingCents => totalPriceCents - receivedCents;
  bool get isFullyPaid => remainingCents <= 0;
  double get paymentProgress =>
      totalPriceCents > 0 ? receivedCents / totalPriceCents : 0.0;

  Order copyWith({
    String? id,
    String? title,
    String? customerId,
    String? customerName,
    String? description,
    String? notes,
    int? totalPriceCents,
    int? receivedCents,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      title: title ?? this.title,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      totalPriceCents: totalPriceCents ?? this.totalPriceCents,
      receivedCents: receivedCents ?? this.receivedCents,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'customerId': customerId,
        'customerName': customerName,
        'description': description,
        'notes': notes,
        'totalPriceCents': totalPriceCents,
        'receivedCents': receivedCents,
        'status': status.toStoredString(),
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Order.fromMap(Map<String, dynamic> map) => Order(
        id: map['id'] as String,
        title: map['title'] as String,
        customerId: map['customerId'] as String,
        customerName: map['customerName'] as String? ?? '',
        description: map['description'] as String?,
        notes: map['notes'] as String?,
        totalPriceCents: (map['totalPriceCents'] as num).toInt(),
        receivedCents: (map['receivedCents'] as num?)?.toInt() ?? 0,
        status: OrderStatus.fromString(map['status'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String),
        dueDate: map['dueDate'] != null
            ? DateTime.parse(map['dueDate'] as String)
            : null,
        updatedAt: map['updatedAt'] != null
            ? DateTime.parse(map['updatedAt'] as String)
            : null,
      );
}

/// A payment recorded against an order.
/// Each OrderPayment automatically generates a Transaction.
class OrderPayment {
  const OrderPayment({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.amountCents,
    required this.paidAt,
    this.notes,
    this.transactionId,
  });

  final String id;
  final String orderId;
  final String customerId;
  final int amountCents;
  final DateTime paidAt;
  final String? notes;
  final String? transactionId; // linked transaction

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'customerId': customerId,
        'amountCents': amountCents,
        'paidAt': paidAt.toIso8601String(),
        'notes': notes,
        'transactionId': transactionId,
      };

  factory OrderPayment.fromMap(Map<String, dynamic> map) => OrderPayment(
        id: map['id'] as String,
        orderId: map['orderId'] as String,
        customerId: map['customerId'] as String,
        amountCents: (map['amountCents'] as num).toInt(),
        paidAt: DateTime.parse(map['paidAt'] as String),
        notes: map['notes'] as String?,
        transactionId: map['transactionId'] as String?,
      );
}
