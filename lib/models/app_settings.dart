/// Application-wide settings stored in SharedPreferences.
class AppSettings {
  const AppSettings({
    required this.businessName,
    required this.ownerName,
    required this.currency,
    required this.locale,
    required this.themeMode,
    required this.dateFormat,
    this.isOnboardingDone = false,
  });

  final String businessName;
  final String ownerName;
  final String currency;   // e.g. 'RUB', 'USD'
  final String locale;     // e.g. 'ru', 'en'
  final String themeMode; // kept in storage; the app always renders light
  final String dateFormat; // 'dd.MM.yyyy' | 'MM/dd/yyyy'
  final bool isOnboardingDone;

  static AppSettings get defaults => const AppSettings(
        businessName: '',
        ownerName: '',
        currency: 'RUB',
        locale: 'ru',
        themeMode: 'light',
        dateFormat: 'dd.MM.yyyy',
        isOnboardingDone: false,
      );

  AppSettings copyWith({
    String? businessName,
    String? ownerName,
    String? currency,
    String? locale,
    String? themeMode,
    String? dateFormat,
    bool? isOnboardingDone,
  }) {
    return AppSettings(
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      currency: currency ?? this.currency,
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      dateFormat: dateFormat ?? this.dateFormat,
      isOnboardingDone: isOnboardingDone ?? this.isOnboardingDone,
    );
  }

  Map<String, dynamic> toMap() => {
        'businessName': businessName,
        'ownerName': ownerName,
        'currency': currency,
        'locale': locale,
        'themeMode': themeMode,
        'dateFormat': dateFormat,
        'isOnboardingDone': isOnboardingDone ? 1 : 0,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        businessName: map['businessName'] as String? ?? '',
        ownerName: map['ownerName'] as String? ?? '',
        currency: map['currency'] as String? ?? 'RUB',
        locale: map['locale'] as String? ?? 'ru',
        themeMode: map['themeMode'] as String? ?? 'light',
        dateFormat: map['dateFormat'] as String? ?? 'dd.MM.yyyy',
        isOnboardingDone: (map['isOnboardingDone'] as int? ?? 0) == 1,
      );
}
