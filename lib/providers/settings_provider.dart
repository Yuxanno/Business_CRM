import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_tr.dart';
import '../models/app_settings.dart';
import '../models/transaction.dart';
import '../repositories/settings_repository.dart';
import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  final _repo = SettingsRepository();

  static const _customIncomeKey = 'settings_custom_income_categories';
  static const _customExpenseKey = 'settings_custom_expense_categories';
  static const _hiddenCategoriesKey = 'settings_hidden_categories';
  static const _renamedCategoriesKey = 'settings_renamed_categories';

  AppSettings _settings = AppSettings.defaults;
  bool _isLoading = true;

  List<String> _customIncomeCategories = [];
  List<String> _customExpenseCategories = [];
  Set<String> _hiddenCategories = {};
  Map<String, String> _renamedCategories = {};

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isOnboardingDone => _settings.isOnboardingDone;

  String get currency => _settings.currency;
  String get locale => _settings.locale;

  List<String> get incomeCategories => [
        ...TransactionCategories.income
            .where((c) => !_hiddenCategories.contains(c)),
        ..._customIncomeCategories,
      ];

  List<String> get expenseCategories => [
        ...TransactionCategories.expense
            .where((c) => !_hiddenCategories.contains(c)),
        ..._customExpenseCategories,
      ];

  bool get hasHiddenDefaultCategories =>
      _hiddenCategories.isNotEmpty || _renamedCategories.isNotEmpty;

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    _customIncomeCategories =
        List<String>.from(prefs.getStringList(_customIncomeKey) ?? const []);
    _customExpenseCategories =
        List<String>.from(prefs.getStringList(_customExpenseKey) ?? const []);
    _hiddenCategories = Set<String>.from(
      prefs.getStringList(_hiddenCategoriesKey) ?? const [],
    );

    final renamedRaw = prefs.getString(_renamedCategoriesKey);
    if (renamedRaw != null && renamedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(renamedRaw) as Map<String, dynamic>;
        _renamedCategories =
            decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        _renamedCategories = {};
      }
    } else {
      _renamedCategories = {};
    }
    TransactionCategories.customLabels
      ..clear()
      ..addAll(_renamedCategories);
  }

  Future<void> _saveCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_customIncomeKey, _customIncomeCategories);
      await prefs.setStringList(_customExpenseKey, _customExpenseCategories);
      await prefs.setStringList(
        _hiddenCategoriesKey,
        _hiddenCategories.toList(),
      );
      await prefs.setString(
        _renamedCategoriesKey,
        jsonEncode(_renamedCategories),
      );
    } catch (_) {}
  }

  /// Adds a new category for [type] and returns its key/name.
  Future<String?> addCategory(TransactionType type, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return null;

    _customIncomeCategories = List<String>.from(_customIncomeCategories);
    _customExpenseCategories = List<String>.from(_customExpenseCategories);
    _hiddenCategories = Set<String>.from(_hiddenCategories);
    _renamedCategories = Map<String, String>.from(_renamedCategories);

    final isIncome = type == TransactionType.income;
    final currentList = isIncome ? incomeCategories : expenseCategories;

    // Check if an existing category already has this key or label
    final existing = currentList.where((c) {
      final label = TransactionCategories.labelFor(c).toLowerCase();
      return c.toLowerCase() == name.toLowerCase() ||
          label == name.toLowerCase();
    }).firstOrNull;

    if (existing != null) {
      return existing;
    }

    // Check if it was a hidden built-in category
    final builtInList = isIncome
        ? TransactionCategories.income
        : TransactionCategories.expense;
    final hiddenMatch = builtInList.where((c) {
      final label = TransactionCategories.labelFor(c).toLowerCase();
      return c.toLowerCase() == name.toLowerCase() ||
          label == name.toLowerCase();
    }).firstOrNull;

    if (hiddenMatch != null && _hiddenCategories.contains(hiddenMatch)) {
      _hiddenCategories.remove(hiddenMatch);
      notifyListeners();
      await _saveCategories();
      return hiddenMatch;
    }

    if (isIncome) {
      _customIncomeCategories.add(name);
    } else {
      _customExpenseCategories.add(name);
    }
    notifyListeners();
    await _saveCategories();
    return name;
  }

  /// Renames a category (built-in or custom).
  Future<void> renameCategory(
    TransactionType type,
    String key,
    String rawNewName,
  ) async {
    final newName = rawNewName.trim();
    if (newName.isEmpty) return;

    _customIncomeCategories = List<String>.from(_customIncomeCategories);
    _customExpenseCategories = List<String>.from(_customExpenseCategories);
    _renamedCategories = Map<String, String>.from(_renamedCategories);

    if (type == TransactionType.income &&
        _customIncomeCategories.contains(key)) {
      final idx = _customIncomeCategories.indexOf(key);
      _customIncomeCategories[idx] = newName;
      _renamedCategories[key] = newName;
    } else if (type == TransactionType.expense &&
        _customExpenseCategories.contains(key)) {
      final idx = _customExpenseCategories.indexOf(key);
      _customExpenseCategories[idx] = newName;
      _renamedCategories[key] = newName;
    } else {
      _renamedCategories[key] = newName;
    }

    TransactionCategories.customLabels[key] = newName;
    notifyListeners();
    await _saveCategories();
  }

  /// Removes a category (either custom or built-in).
  Future<void> removeCategory(TransactionType type, String key) async {
    _customIncomeCategories = List<String>.from(_customIncomeCategories);
    _customExpenseCategories = List<String>.from(_customExpenseCategories);
    _hiddenCategories = Set<String>.from(_hiddenCategories);

    if (type == TransactionType.income) {
      if (_customIncomeCategories.contains(key)) {
        _customIncomeCategories.remove(key);
      } else {
        _hiddenCategories.add(key);
      }
    } else {
      if (_customExpenseCategories.contains(key)) {
        _customExpenseCategories.remove(key);
      } else {
        _hiddenCategories.add(key);
      }
    }
    notifyListeners();
    await _saveCategories();
  }

  /// Restores any deleted or renamed default categories.
  Future<void> restoreDefaultCategories() async {
    _hiddenCategories = {};
    _renamedCategories = {};
    TransactionCategories.customLabels.clear();
    notifyListeners();
    await _saveCategories();
  }

  Future<void> init({bool skipRemoteSync = false}) async {
    _isLoading = true;
    notifyListeners();
    _settings = await _repo.load();
    AppTr.isEn = _settings.locale == 'en';
    await _loadCategories();
    _isLoading = false;
    notifyListeners();
    if (!skipRemoteSync && _settings.isOnboardingDone) {
      _syncFromServer();
    }
  }

  Future<void> applyServerUser(Map<String, dynamic> user) async {
    final nextCurrency =
        (user['currency'] ?? '').toString().isNotEmpty
            ? user['currency'].toString()
            : _settings.currency;
    final nextLocale =
        (user['locale'] ?? '').toString().isNotEmpty
            ? user['locale'].toString()
            : _settings.locale;
    final nextBusiness =
        user['businessName'] != null
            ? user['businessName'].toString()
            : _settings.businessName;
    final nextOwner =
        (user['name'] ?? '').toString().isNotEmpty
            ? user['name'].toString()
            : _settings.ownerName;

    if (nextCurrency == _settings.currency &&
        nextLocale == _settings.locale &&
        nextBusiness == _settings.businessName &&
        nextOwner == _settings.ownerName) {
      return;
    }

    _settings = _settings.copyWith(
      currency: nextCurrency,
      locale: nextLocale,
      businessName: nextBusiness,
      ownerName: nextOwner,
    );
    AppTr.isEn = _settings.locale == 'en';
    await _repo.save(_settings);
    notifyListeners();
    unawaited(NotificationService.instance.onLocaleChanged(_settings.locale));
  }

  Future<void> reload() async {
    _isLoading = true;
    notifyListeners();
    _settings = await _repo.load();
    AppTr.isEn = _settings.locale == 'en';
    await _loadCategories();
    _isLoading = false;
    notifyListeners();
    _syncFromServer();
  }

  Future<void> _syncFromServer() async {
    final server = await _repo.fetchServerProfile();
    if (server == null) return;

    final nextCurrency = server['currency'] ?? _settings.currency;
    final nextLocale = server['locale'] ?? _settings.locale;
    final nextBusiness = server['businessName'] ?? _settings.businessName;
    final nextOwner = server['ownerName'] ?? _settings.ownerName;

    if (nextCurrency == _settings.currency &&
        nextLocale == _settings.locale &&
        nextBusiness == _settings.businessName &&
        nextOwner == _settings.ownerName) {
      return;
    }

    _settings = _settings.copyWith(
      currency: nextCurrency,
      locale: nextLocale,
      businessName: nextBusiness,
      ownerName: nextOwner,
    );
    AppTr.isEn = _settings.locale == 'en';
    await _repo.save(_settings);
    notifyListeners();
    unawaited(NotificationService.instance.onLocaleChanged(_settings.locale));
  }

  Future<void> update(AppSettings updated) async {
    _settings = updated;
    AppTr.isEn = _settings.locale == 'en';
    // UI updates instantly; persistence happens afterwards.
    notifyListeners();
    await _repo.save(_settings);
    unawaited(NotificationService.instance.onLocaleChanged(_settings.locale));
  }

  Future<void> completeOnboarding({
    required String businessName,
    required String ownerName,
    required String currency,
    required String locale,
    required String themeMode,
  }) async {
    _settings = _settings.copyWith(
      businessName: businessName,
      ownerName: ownerName,
      currency: currency,
      locale: locale,
      themeMode: themeMode,
      isOnboardingDone: true,
    );
    AppTr.isEn = locale == 'en';
    await _repo.save(_settings);
    notifyListeners();
    unawaited(NotificationService.instance.onLocaleChanged(_settings.locale));
  }

  Future<void> setLocale(String locale) async {
    AppTr.isEn = locale == 'en';
    _settings = _settings.copyWith(locale: locale);
    await _repo.save(_settings);
    notifyListeners();
    unawaited(NotificationService.instance.onLocaleChanged(locale));

    try {
      await _repo.syncToServer(locale: locale);
    } catch (_) {}
  }

  Future<void> setCurrency(String currency) async {
    _settings = _settings.copyWith(currency: currency);
    await _repo.save(_settings);
    notifyListeners();

    try {
      await _repo.syncToServer(currency: currency);
    } catch (_) {}
  }
}
