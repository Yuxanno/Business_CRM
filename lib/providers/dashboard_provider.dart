import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/debt_repository.dart';

/// Aggregates all data needed for the Home dashboard.
class DashboardProvider extends ChangeNotifier {
  final _txRepo = TransactionRepository();
  final _orderRepo = OrderRepository();
  final _customerRepo = CustomerRepository();
  final _debtRepo = DebtRepository();

  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  int _incomeCents = 0;
  int _expenseCents = 0;
  int _activeOrdersCount = 0;
  int _totalCustomersCount = 0;
  int _receivableCents = 0;
  List<AppTransaction> _recentActivity = [];
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = false;
  String? _error;

  int get year => _year;
  int get month => _month;
  int get incomeCents => _incomeCents;
  int get expenseCents => _expenseCents;
  int get netCents => _incomeCents - _expenseCents;
  int get activeOrdersCount => _activeOrdersCount;
  int get totalCustomersCount => _totalCustomersCount;
  int get receivableCents => _receivableCents;
  List<AppTransaction> get recentActivity => _recentActivity;
  List<Map<String, dynamic>> get chartData => _chartData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load({int? year, int? month}) async {
    if (year != null) _year = year;
    if (month != null) _month = month;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _txRepo.getTotalIncomeCents(_year, _month),
        _txRepo.getTotalExpenseCents(_year, _month),
        _orderRepo.getActiveCount(),
        _debtRepo.getTotalReceivableCents(),
        _txRepo.getDailyTotals(_year, _month),
      ]);

      _incomeCents = results[0] as int;
      _expenseCents = results[1] as int;
      _activeOrdersCount = results[2] as int;
      _receivableCents = results[3] as int;
      _chartData = results[4] as List<Map<String, dynamic>>;

      final customers = await _customerRepo.getAll();
      _totalCustomersCount = customers.length;

      final allTx = await _txRepo.getAll();
      _recentActivity = allTx.take(15).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();

  void setMonth(int year, int month) => load(year: year, month: month);
}
