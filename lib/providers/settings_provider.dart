import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final _repo = SettingsRepository();

  AppSettings _settings = AppSettings.defaults;
  bool _isLoading = true;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isOnboardingDone => _settings.isOnboardingDone;

  String get currency => _settings.currency;
  String get locale => _settings.locale;
  String get themeMode => _settings.themeMode;

  Future<void> init() async {
    _settings = await _repo.load();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> update(AppSettings updated) async {
    _settings = updated;
    await _repo.save(_settings);
    notifyListeners();
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
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<void> setTheme(String themeMode) async {
    _settings = _settings.copyWith(themeMode: themeMode);
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _settings = _settings.copyWith(locale: locale);
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    _settings = _settings.copyWith(currency: currency);
    await _repo.save(_settings);
    notifyListeners();
  }
}
