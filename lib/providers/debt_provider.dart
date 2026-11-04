import 'package:flutter/material.dart';
import '../models/debt.dart';
import '../repositories/debt_repository.dart';
import '../services/database_service.dart';

class DebtProvider extends ChangeNotifier {
  final _repo = DebtRepository();

  List<Debt> _debts = [];
  bool _isLoading = false;
  String? _error;

  List<Debt> get receivables =>
      _debts.where((d) => d.direction == DebtDirection.receivable).toList();

  List<Debt> get payables =>
      _debts.where((d) => d.direction == DebtDirection.payable).toList();

  List<Debt> get all => _debts;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _debts = await _repo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Debt?> getById(String id) => _repo.getById(id);

  Future<void> add(Debt debt) async {
    await _repo.insert(debt);
    await load();
  }

  Future<void> update(Debt debt) async {
    await _repo.update(debt);
    final idx = _debts.indexWhere((d) => d.id == debt.id);
    if (idx != -1) {
      _debts[idx] = debt;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _debts.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  /// Records a payment toward a debt.
  /// 1. Creates DebtPayment
  /// 2. Creates a Transaction
  /// 3. Updates debt paidAmountCents and status
  Future<void> recordPayment({
    required String debtId,
    required int amountCents,
    required String paymentId,
    required String transactionId,
    DateTime? paidAt,
    String? notes,
  }) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    final now = paidAt ?? DateTime.now();

    // Clamp: cannot pay more than remaining
    final clamped = amountCents.clamp(0, debt.remainingCents);
    if (clamped <= 0) return;

    final newPaid = debt.paidAmountCents + clamped;
    final updatedDebt = debt.copyWith(
      paidAmountCents: newPaid,
      status: _computeStatus(debt.copyWith(paidAmountCents: newPaid)),
      updatedAt: now,
    );

    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      // Update debt
      await txn.update(
        'debts',
        updatedDebt.toMap(),
        where: 'id = ?',
        whereArgs: [debtId],
      );

      // Insert debt payment
      await txn.insert('debt_payments', {
        'id': paymentId,
        'debtId': debtId,
        'amountCents': clamped,
        'paidAt': now.toIso8601String(),
        'notes': notes,
        'transactionId': transactionId,
      });

      // Insert transaction
      // Receivable payment = income (someone paid me)
      // Payable payment = expense (I paid someone)
      final txType = debt.direction == DebtDirection.receivable
          ? 'income'
          : 'expense';
      await txn.insert('transactions', {
        'id': transactionId,
        'amountCents': clamped,
        'type': txType,
        'category': debt.direction == DebtDirection.receivable
            ? 'debt_received'
            : 'debt_paid',
        'description': 'Debt payment: ${debt.personName}',
        'date': now.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'debtId': debtId,
        'linkedEntityType': 'debt_payment',
        'linkedEntityId': paymentId,
      });
    });

    final idx = _debts.indexWhere((d) => d.id == debtId);
    if (idx != -1) {
      _debts[idx] = updatedDebt;
      notifyListeners();
    }
  }

  Future<List<DebtPayment>> getPaymentsForDebt(String debtId) =>
      _repo.getPaymentsForDebt(debtId);

  Future<int> getTotalReceivableCents() => _repo.getTotalReceivableCents();
  Future<int> getTotalPayableCents() => _repo.getTotalPayableCents();

  DebtStatus _computeStatus(Debt debt) {
    if (debt.paidAmountCents >= debt.originalAmountCents) {
      return DebtStatus.paid;
    }
    if (debt.paidAmountCents > 0) {
      if (debt.dueDate != null && DateTime.now().isAfter(debt.dueDate!)) {
        return DebtStatus.overdue;
      }
      return DebtStatus.partiallyPaid;
    }
    if (debt.dueDate != null && DateTime.now().isAfter(debt.dueDate!)) {
      return DebtStatus.overdue;
    }
    return DebtStatus.unpaid;
  }
}
