/// Represents a business customer.
/// Customers are global records — not month-specific.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.createdAt,
    this.phone,
    this.email,
    this.notes,
    this.totalOrdersAmountCents = 0,
    this.totalReceivedCents = 0,
    this.totalOrdersCount = 0,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime createdAt;

  /// Denormalized aggregates — updated when orders/payments change.
  final int totalOrdersAmountCents;
  final int totalReceivedCents;
  final int totalOrdersCount;

  int get outstandingBalanceCents =>
      totalOrdersAmountCents - totalReceivedCents;

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? notes,
    DateTime? createdAt,
    int? totalOrdersAmountCents,
    int? totalReceivedCents,
    int? totalOrdersCount,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      totalOrdersAmountCents:
          totalOrdersAmountCents ?? this.totalOrdersAmountCents,
      totalReceivedCents: totalReceivedCents ?? this.totalReceivedCents,
      totalOrdersCount: totalOrdersCount ?? this.totalOrdersCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'totalOrdersAmountCents': totalOrdersAmountCents,
        'totalReceivedCents': totalReceivedCents,
        'totalOrdersCount': totalOrdersCount,
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        totalOrdersAmountCents:
            map['totalOrdersAmountCents'] as int? ?? 0,
        totalReceivedCents: map['totalReceivedCents'] as int? ?? 0,
        totalOrdersCount: map['totalOrdersCount'] as int? ?? 0,
      );
}
