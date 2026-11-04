import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import '../../components/app_button.dart';
import '../../components/app_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _businessNameCtrl.text = settings.businessName;
    _ownerNameCtrl.text = settings.ownerName;
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final settings = context.read<SettingsProvider>().settings;
      await context.read<SettingsProvider>().update(
            settings.copyWith(
              businessName: _businessNameCtrl.text.trim(),
              ownerName: _ownerNameCtrl.text.trim(),
            ),
          );
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль обновлён')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = context.watch<SettingsProvider>().settings;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          // Business profile section
          _SectionHeader(label: 'Профиль бизнеса'),
          AppCard(
            child: Column(
              children: [
                TextFormField(
                  controller: _businessNameCtrl,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Название бизнеса',
                    hintText: 'ИП Иванов / Студия дизайна',
                    border: InputBorder.none,
                  ),
                ),
                Divider(color: colors.divider, height: 1),
                TextFormField(
                  controller: _ownerNameCtrl,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Имя владельца',
                    hintText: 'Иван Иванов',
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Сохранить профиль',
            onPressed: _saveProfile,
            isLoading: _saving,
            variant: AppButtonVariant.secondary,
            icon: Icons.check_rounded,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Appearance
          _SectionHeader(label: 'Внешний вид'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _PickerTile(
                  label: 'Тема',
                  value: _themeLabel(settings.themeMode),
                  icon: Icons.palette_outlined,
                  iconColor: colors.primary,
                  onTap: () => _showThemePicker(context, settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Currency & Locale
          _SectionHeader(label: 'Региональные настройки'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _PickerTile(
                  label: 'Валюта',
                  value: settings.currency,
                  icon: Icons.payments_outlined,
                  iconColor: colors.income,
                  onTap: () => _showCurrencyPicker(context),
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.xl + 36,
                    color: colors.divider),
                _PickerTile(
                  label: 'Язык',
                  value: settings.locale == 'ru' ? 'Русский' : 'English',
                  icon: Icons.language_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  onTap: () => _showLocalePicker(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, AppSettings settings) {
    final colors = context.appColors;
    final options = [
      ('system', 'Как в системе', Icons.brightness_auto_outlined),
      ('light', 'Светлая', Icons.light_mode_outlined),
      ('dark', 'Тёмная', Icons.dark_mode_outlined),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тема оформления',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            ...options.map((o) {
              final isSelected = settings.themeMode == o.$1;
              return ListTile(
                leading: Icon(o.$3,
                    color: isSelected ? colors.primary : colors.textSecondary),
                title: Text(o.$2,
                    style: TextStyle(
                        color: isSelected
                            ? colors.primary
                            : colors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400)),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: colors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  context.read<SettingsProvider>().setTheme(o.$1);
                },
              );
            }),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    final colors = context.appColors;
    const currencies = [
      ('RUB', '₽ Российский рубль'),
      ('USD', '\$ Доллар США'),
      ('EUR', '€ Евро'),
      ('KZT', '₸ Казахстанский тенге'),
      ('UZS', 'сўм Узбекский сум'),
      ('GBP', '£ Фунт стерлингов'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) {
        final current = context.read<SettingsProvider>().currency;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Валюта',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary)),
              const SizedBox(height: AppSpacing.lg),
              ...currencies.map((c) {
                final isSelected = current == c.$1;
                return ListTile(
                  title: Text(c.$2,
                      style: TextStyle(
                          color: isSelected
                              ? colors.primary
                              : colors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400)),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    context.read<SettingsProvider>().setCurrency(c.$1);
                  },
                );
              }),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  void _showLocalePicker(BuildContext context) {
    final colors = context.appColors;
    const locales = [
      ('ru', 'Русский'),
      ('en', 'English'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) {
        final current = context.read<SettingsProvider>().locale;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Язык интерфейса',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary)),
              const SizedBox(height: AppSpacing.lg),
              ...locales.map((l) {
                final isSelected = current == l.$1;
                return ListTile(
                  title: Text(l.$2,
                      style: TextStyle(
                          color: isSelected
                              ? colors.primary
                              : colors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400)),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    context.read<SettingsProvider>().setLocale(l.$1);
                  },
                );
              }),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  String _themeLabel(String mode) => switch (mode) {
        'light' => 'Светлая',
        'dark' => 'Тёмная',
        _ => 'Как в системе',
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
