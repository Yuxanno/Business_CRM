import 'dart:async';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';
import '../services/local_cache.dart';

/// Aggregates all data needed for the Home dashboard with instant local cache
/// (Stale-While-Revalidate) so the UI renders immediately regardless of network.
class DashboardProvider extends ChangeNotifier {
  final _api = ApiClient.instance;

  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  int _incomeCents = 0;
  int _expenseCents = 0;
  int _activeOrdersCount = 0;
  int _totalCustomersCount = 0;
  int _receivableCents = 0;
  int _payableCents = 0;
  List<AppTransaction> _recentActivity = [];
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = false;
  bool _hasData = false;
  bool _hasLoadedOnce = false;
  DateTime? _lastFetchedAt;
  String? _error;

  int get year => _year;
  int get month => _month;
  int get incomeCents => _incomeCents;
  int get expenseCents => _expenseCents;
  int get netCents => _incomeCents - _expenseCents;
  int get activeOrdersCount => _activeOrdersCount;
  int get totalCustomersCount => _totalCustomersCount;
  int get receivableCents => _receivableCents;
  int get payableCents => _payableCents;
  List<AppTransaction> get recentActivity => _recentActivity;
  List<Map<String, dynamic>> get chartData => _chartData;
  bool get isLoading => _isLoading && !_hasData;
  bool get isRefreshing => _isLoading;
  bool get hasData => _hasData;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  void _applyPayload(Map<String, dynamic> json) {
    _incomeCents = (json['incomeCents'] as num?)?.toInt() ?? 0;
    _expenseCents = (json['expenseCents'] as num?)?.toInt() ?? 0;
    _activeOrdersCount = (json['activeOrdersCount'] as num?)?.toInt() ?? 0;
    _receivableCents = (json['receivableCents'] as num?)?.toInt() ?? 0;
    _payableCents = (json['payableCents'] as num?)?.toInt() ?? 0;
    _totalCustomersCount =
        (json['totalCustomersCount'] as num?)?.toInt() ?? 0;
    final chart = (json['chartData'] as List?) ?? const [];
    _chartData =
        chart.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final recent = (json['recent'] as List?) ?? const [];
    _recentActivity = recent
        .map((e) =>
            AppTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    _hasData = true;
  }

  Future<void> hydrateFromCache() async {
    if (_hasData) return;
    final cacheKey = 'dashboard_${_year}_$_month';
    final cached = await LocalCache.readMap(cacheKey);
    if (cached != null) {
      _applyPayload(cached);
      notifyListeners();
    }
  }

  void applyBootstrapPayload(
    Map<String, dynamic> json, {
    required int year,
    required int month,
  }) {
    _year = year;
    _month = month;
    _applyPayload(json);
    _hasLoadedOnce = true;
    _isLoading = false;
    _lastFetchedAt = DateTime.now();
    notifyListeners();
    unawaited(LocalCache.writeMap('dashboard_${_year}_$_month', json));
  }

  Future<void> load({int? year, int? month, bool force = false}) async {
    final periodChanged =
        (year != null && year != _year) || (month != null && month != _month);
    if (year != null) _year = year;
    if (month != null) _month = month;

    if (!force &&
        !periodChanged &&
        _hasData &&
        _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!) <
            const Duration(seconds: 20)) {
      return;
    }

    final cacheKey = 'dashboard_${_year}_$_month';

    if (_isLoading && !periodChanged) return;
    _isLoading = true;
    _error = null;
    if (periodChanged || !_hasData) {
      notifyListeners();
    }

    // 1. Instant local snapshot so Home renders in < 50ms
    if (!_hasData || periodChanged) {
      final cached = await LocalCache.readMap(cacheKey);
      if (cached != null) {
        _applyPayload(cached);
        notifyListeners();
      }
    }

    try {
      final raw = await _api.get('/api/dashboard?year=$_year&month=$_month&tz=${DateTime.now().timeZoneOffset.inMinutes}');
      if (raw is Map) {
        final json = Map<String, dynamic>.from(raw);
        _applyPayload(json);
        _lastFetchedAt = DateTime.now();
        unawaited(LocalCache.writeMap(cacheKey, json));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  /// Lightweight summary fetch used by Profile/More screen (only counts & debt totals).
  Future<void> loadSummaryOnly() async {
    try {
      final raw = await _api.get('/api/dashboard/summary');
      if (raw is Map) {
        _activeOrdersCount =
            (raw['activeOrdersCount'] as num?)?.toInt() ?? _activeOrdersCount;
        _totalCustomersCount = (raw['totalCustomersCount'] as num?)?.toInt() ??
            _totalCustomersCount;
        _receivableCents =
            (raw['receivableCents'] as num?)?.toInt() ?? _receivableCents;
        _payableCents =
            (raw['payableCents'] as num?)?.toInt() ?? _payableCents;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> reload() => load(force: true);

  void setMonth(int year, int month) {
    _hasData = false;
    load(year: year, month: month, force: true);
  }
}
