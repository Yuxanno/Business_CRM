import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';

class CustomerProvider extends ChangeNotifier {
  final _repo = CustomerRepository();

  List<Customer> _customers = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<Customer> get customers => _searchQuery.isEmpty
      ? _customers
      : _customers
          .where((c) =>
              c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (c.phone?.contains(_searchQuery) ?? false))
          .toList();

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCount => _customers.length;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _customers = await _repo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<Customer?> getById(String id) => _repo.getById(id);

  Future<void> add(Customer customer) async {
    await _repo.insert(customer);
    await load();
  }

  Future<void> update(Customer customer) async {
    await _repo.update(customer);
    final idx = _customers.indexWhere((c) => c.id == customer.id);
    if (idx != -1) {
      _customers[idx] = customer;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Called after an order payment to keep customer stats in sync.
  Future<void> recordPayment(String customerId, int amountCents) async {
    await _repo.addPayment(customerId, amountCents);
    final updated = await _repo.getById(customerId);
    if (updated != null) {
      final idx = _customers.indexWhere((c) => c.id == customerId);
      if (idx != -1) {
        _customers[idx] = updated;
        notifyListeners();
      }
    }
  }

  /// Called when a new order is created.
  Future<void> recordNewOrder(
      String customerId, int orderAmountCents) async {
    await _repo.addOrder(customerId, orderAmountCents);
    final updated = await _repo.getById(customerId);
    if (updated != null) {
      final idx = _customers.indexWhere((c) => c.id == customerId);
      if (idx != -1) {
        _customers[idx] = updated;
        notifyListeners();
      }
    }
  }
}
