/// Debt direction.
enum DebtDirection {
  /// Customer owes me money.
  receivable,

  /// I owe someone money.
  payable;

  static DebtDirection fromString(String v) =>
      v == 'payable' ? DebtDirection.payable : DebtDirection.receivable;

  String toStoredString() => name;
}

/// Debt status.
enum DebtStatus {
  unpaid,
  partiallyPaid,
  paid,
  overdue;

  static DebtStatus fromString(String v) => switch (v) {
        'partiallyPaid' => DebtStatus.partiallyPaid,
        'paid' => DebtStatus.paid,
        'overdue' => DebtStatus.overdue,
        _ => DebtStatus.unpaid,
      };

  String toStoredString() => switch (this) {
        DebtStatus.unpaid => 'unpaid',
        DebtStatus.partiallyPaid => 'partiallyPaid',
        DebtStatus.paid => 'paid',
        DebtStatus.overdue => 'overdue',
      };
}

/// A standalone debt record.
class Debt {
  const Debt({
    required this.id,
    required this.personName,
    required this.direction,
    required this.originalAmountCents,
    required this.paidAmountCents,
    required this.status,
    required this.createdAt,
    this.customerId,
    this.description,
    this.dueDate,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String personName;
  final String? customerId; // optional link to Customer
  final DebtDirection direction;
  final int originalAmountCents;
  final int paidAmountCents;
  final DebtStatus status;
  final String? description;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String? notes;
  final DateTime? updatedAt;

  int get remainingCents => originalAmountCents - paidAmountCents;
  bool get isFullyPaid => remainingCents <= 0;

  /// Compute correct status based on amounts and due date.
  DebtStatus get computedStatus {
    if (paidAmountCents >= originalAmountCents) return DebtStatus.paid;
    if (paidAmountCents > 0) {
      if (dueDate != null && DateTime.now().isAfter(dueDate!)) {
        return DebtStatus.overdue;
      }
      return DebtStatus.partiallyPaid;
    }
    if (dueDate != null && DateTime.now().isAfter(dueDate!)) {
      return DebtStatus.overdue;
    }
    return DebtStatus.unpaid;
  }

  Debt copyWith({
    String? id,
    String? personName,
    String? customerId,
    DebtDirection? direction,
    int? originalAmountCents,
    int? paidAmountCents,
    DebtStatus? status,
    String? description,
    DateTime? createdAt,
    DateTime? dueDate,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      customerId: customerId ?? this.customerId,
      direction: direction ?? this.direction,
      originalAmountCents: originalAmountCents ?? this.originalAmountCents,
      paidAmountCents: paidAmountCents ?? this.paidAmountCents,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'personName': personName,
        'customerId': customerId,
        'direction': direction.toStoredString(),
        'originalAmountCents': originalAmountCents,
        'paidAmountCents': paidAmountCents,
        'status': status.toStoredString(),
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'notes': notes,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Debt.fromMap(Map<String, dynamic> map) => Debt(
        id: map['id'] as String,
        personName: map['personName'] as String,
        customerId: map['customerId'] as String?,
        direction: DebtDirection.fromString(map['direction'] as String),
        originalAmountCents: map['originalAmountCents'] as int,
        paidAmountCents: map['paidAmountCents'] as int? ?? 0,
        status: DebtStatus.fromString(map['status'] as String),
        description: map['description'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        dueDate: map['dueDate'] != null
            ? DateTime.parse(map['dueDate'] as String)
            : null,
        notes: map['notes'] as String?,
        updatedAt: map['updatedAt'] != null
            ? DateTime.parse(map['updatedAt'] as String)
            : null,
      );
}

/// A single payment toward a debt.
class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.amountCents,
    required this.paidAt,
    this.notes,
    this.transactionId,
  });

  final String id;
  final String debtId;
  final int amountCents;
  final DateTime paidAt;
  final String? notes;
  final String? transactionId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'debtId': debtId,
        'amountCents': amountCents,
        'paidAt': paidAt.toIso8601String(),
        'notes': notes,
        'transactionId': transactionId,
      };

  factory DebtPayment.fromMap(Map<String, dynamic> map) => DebtPayment(
        id: map['id'] as String,
        debtId: map['debtId'] as String,
        amountCents: map['amountCents'] as int,
        paidAt: DateTime.parse(map['paidAt'] as String),
        notes: map['notes'] as String?,
        transactionId: map['transactionId'] as String?,
      );
}
