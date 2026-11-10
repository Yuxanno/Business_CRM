import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';

/// Aggregates all data needed for the Home dashboard.
class DashboardProvider extends ChangeNotifier {
  final _api = ApiClient.instance;

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
      final json = await _api.get('/api/dashboard?year=$_year&month=$_month');
      _incomeCents = (json['incomeCents'] as num?)?.toInt() ?? 0;
      _expenseCents = (json['expenseCents'] as num?)?.toInt() ?? 0;
      _activeOrdersCount = (json['activeOrdersCount'] as num?)?.toInt() ?? 0;
      _receivableCents = (json['receivableCents'] as num?)?.toInt() ?? 0;
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
