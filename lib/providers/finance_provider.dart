import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

class FinanceProvider extends ChangeNotifier {
  final _repo = TransactionRepository();

  List<AppTransaction> _transactions = [];
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  TransactionType? _typeFilter;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  // Aggregates for selected month
  int _incomeCents = 0;
  int _expenseCents = 0;

  List<AppTransaction> get transactions {
    var list = _transactions;
    if (_typeFilter != null) {
      list = list.where((t) => t.type == _typeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((t) =>
              (t.description?.toLowerCase().contains(q) ?? false) ||
              (t.category?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  int get incomeCents => _incomeCents;
  int get expenseCents => _expenseCents;
  int get netCents => _incomeCents - _expenseCents;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;
  TransactionType? get typeFilter => _typeFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMonth(int year, int month) async {
    _selectedYear = year;
    _selectedMonth = month;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _transactions = await _repo.getForMonth(year, month);
      _incomeCents = await _repo.getTotalIncomeCents(year, month);
      _expenseCents = await _repo.getTotalExpenseCents(year, month);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => loadMonth(_selectedYear, _selectedMonth);

  void setTypeFilter(TransactionType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> add(AppTransaction tx) async {
    await _repo.insert(tx);
    await reload();
  }

  Future<void> update(AppTransaction tx) async {
    await _repo.update(tx);
    await reload();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _transactions.removeWhere((t) => t.id == id);
    // Recompute aggregates
    _incomeCents = _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0, (sum, t) => sum + t.amountCents);
    _expenseCents = _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0, (sum, t) => sum + t.amountCents);
    notifyListeners();
  }

  /// Returns daily chart data for the selected month.
  Future<List<Map<String, dynamic>>> getDailyTotals() =>
      _repo.getDailyTotals(_selectedYear, _selectedMonth);

  /// Returns recent transactions across all time (for dashboard).
  Future<List<AppTransaction>> getRecent({int limit = 10}) async {
    final all = await _repo.getAll();
    return all.take(limit).toList();
  }
}
