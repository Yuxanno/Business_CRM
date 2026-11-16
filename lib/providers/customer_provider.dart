import 'dart:async';
import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import '../services/local_cache.dart';

class CustomerProvider extends ChangeNotifier {
  static const int pageSize = 25;
  static const _cacheKey = 'customers_page1';

  final _repo = CustomerRepository();

  List<Customer> _customers = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _hasLoadedOnce = false;
  String? _error;

  List<Customer> get allCustomers => _customers;

  List<Customer> get customers => _searchQuery.isEmpty
      ? _customers
      : _customers
          .where((c) =>
              c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (c.phone?.contains(_searchQuery) ?? false))
          .toList();

  bool get isLoading => _isLoading && _customers.isEmpty;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  /// Real totals reported by the server (independent of how many pages are loaded).
  Map<String, dynamic>? _counts;
  Map<String, dynamic>? get counts => _counts;
  int get totalCount => (_counts?['total'] as num?)?.toInt() ?? _customers.length;
  int get withOrdersCount => (_counts?['withOrders'] as num?)?.toInt() ?? _customers.where((c) => c.totalOrdersCount > 0).length;
  int? get withDebtCountFromServer => (_counts?['withDebt'] as num?)?.toInt();

  Future<void> load({bool silent = false}) async {
    if (_customers.isEmpty) {
      _counts ??= await LocalCache.readMap('${_cacheKey}_counts');
      final cached = await LocalCache.readMap(_cacheKey);
      if (cached != null) {
        final rawItems = (cached['items'] as List?) ?? const [];
        _customers = rawItems
            .map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _hasMore = cached['hasMore'] == true;
        notifyListeners();
      }
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final page = await _repo.getPage(skip: 0, limit: pageSize);
      _customers = page.items;
      _hasMore = page.hasMore;
      _hasLoadedOnce = true;
      unawaited(refreshCounts());

      unawaited(LocalCache.writeMap(_cacheKey, {
        'items': _customers.map((c) => c.toMap()).toList(),
        'hasMore': _hasMore,
      }));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    if (_hasMore) unawaited(loadAll());
  }

  /// Refreshes real totals from the server.
  Future<void> refreshCounts() async {
    try {
      _counts = await _repo.getCounts();
      unawaited(LocalCache.writeMap('${_cacheKey}_counts', _counts!));
      notifyListeners();
    } catch (_) {}
  }

  /// Loads the remaining pages in the background so lists, filters and
  /// counters always reflect everything that really exists.
  Future<void> loadAll({int maxPages = 40}) async {
    var guard = 0;
    while (_hasMore && guard++ < maxPages) {
      if (_isLoadingMore) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        continue;
      }
      final before = _customers.length;
      await loadMore();
      if (_customers.length == before) break;
    }
  }

  Future<void> prefetchIfNeeded() async {
    if (_hasLoadedOnce || _isLoading) return;
    await load(silent: true);
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _repo.getPage(
        skip: _customers.length,
        limit: pageSize,
      );
      final existingIds = _customers.map((c) => c.id).toSet();
      final fresh = page.items.where((c) => !existingIds.contains(c.id));
      _customers = [..._customers, ...fresh];
      _hasMore = page.hasMore;
    } catch (_) {
    } finally {
      _isLoadingMore = false;
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
    unawaited(refreshCounts());
  }

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
