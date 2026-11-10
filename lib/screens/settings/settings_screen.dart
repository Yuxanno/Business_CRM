import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/settings_provider.dart';
import '../../components/app_button.dart';
import '../../components/app_card.dart';
import '../../components/app_templates.dart';
import '../../components/app_modal_sheet.dart';
import '../profile/account_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Reload settings from storage to get latest currency/locale
    context.read<SettingsProvider>().reload();
    final settings = context.read<SettingsProvider>().settings;
    _businessNameCtrl.text = settings.businessName;
    AccountStore.load().then((account) {
      if (!mounted) return;
      setState(() {
        _nameCtrl.text =
            account.name.isNotEmpty ? account.name : settings.ownerName;
        _loginCtrl.text = account.login;
        if (account.businessName.isNotEmpty &&
            _businessNameCtrl.text.trim().isEmpty) {
          _businessNameCtrl.text = account.businessName;
        }
      });
      // Sync currency and locale from server if returned
      final sp = context.read<SettingsProvider>();
      if (account.currency != null || account.locale != null) {
        sp.update(sp.settings.copyWith(
          currency: account.currency ?? sp.settings.currency,
          locale: account.locale ?? sp.settings.locale,
          businessName: account.businessName.isNotEmpty
              ? account.businessName
              : sp.settings.businessName,
          ownerName: account.name.isNotEmpty
              ? account.name
              : sp.settings.ownerName,
        ));
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _businessNameCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final login = _loginCtrl.text.trim();
    final business = _businessNameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty) {
      _toast('Укажите имя пользователя');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]{3,32}$').hasMatch(login)) {
      _toast('Логин: 3–32 символа, латиница, цифры, . _ -');
      return;
    }
    if (password.isNotEmpty && password.length < 6) {
      _toast('Новый пароль — минимум 6 символов');
      return;
    }

    setState(() => _saving = true);
    try {
      final sp = context.read<SettingsProvider>();
      final error = await AccountStore.updateProfile(
        name: name,
        login: login,
        businessName: business,
        password: password,
        currency: sp.settings.currency,
        locale: sp.settings.locale,
      );
      if (!mounted) return;
      if (error != null) {
        _toast(error);
        return;
      }

      await sp.update(
        sp.settings.copyWith(
          businessName: business,
          ownerName: name,
        ),
      );
      _passwordCtrl.clear();
      HapticFeedback.mediumImpact();
      if (mounted) _toast('Профиль сохранён');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = context.watch<SettingsProvider>().settings;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const AppPageTitle(
            title: 'Настройки',
            showBack: true,
            fallbackRoute: '/profile',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _SectionHeader(label: 'Профиль')),
              AppButton(
                label: _saving ? 'Сохранение' : 'Сохранить',
                onPressed: _saving ? null : _saveProfile,
                isLoading: _saving,
                variant: AppButtonVariant.text,
                isFullWidth: false,
                height: 36,
              ),
            ],
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InlineField(
                  label: 'Имя пользователя',
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                ),
                _InlineField(
                  label: 'Название бизнеса',
                  controller: _businessNameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                ),
                _InlineField(
                  label: 'Логин',
                  controller: _loginCtrl,
                ),
                _InlineField(
                  label: 'Новый пароль',
                  controller: _passwordCtrl,
                  obscureText: true,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionHeader(label: 'Суммы и язык'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _PickerTile(
                  label: 'Валюта',
                  value: settings.currency,
                  onTap: () => _showCurrencyPicker(context),
                ),
                Divider(height: 1, color: colors.divider),
                _PickerTile(
                  label: 'Язык',
                  value: settings.locale == 'ru' ? 'Русский' : 'English',
                  onTap: () => _showLocalePicker(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
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
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) {
        final current = context.read<SettingsProvider>().currency;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
              children: [
                Text('Валюта',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                ...currencies.map((c) {
                  final isSelected = current == c.$1;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
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
              ],
            ),
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
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textMuted,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
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
              horizontal: AppSpacing.lg, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
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

// ─── Inline editable field ────────────────────────────────────────────────────

/// Floating-label inline field.
/// When empty and unfocused: label sits in the middle like a placeholder.
/// When focused or has a value: label floats to the top, value is shown below.
class _InlineField extends StatefulWidget {
  const _InlineField({
    required this.label,
    required this.controller,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.isLast = false,
  });

  final String label;
  final TextEditingController controller;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool isLast;

  @override
  State<_InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<_InlineField> {
  final _focusNode = FocusNode();
  bool _focused = false;
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
    // Rebuild when text changes so the label floats correctly.
    widget.controller.addListener(_onTextChange);
  }

  void _onTextChange() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: _obscured,
            textCapitalization: widget.textCapitalization,
            style: TextStyle(
              fontSize: 15,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: TextStyle(
                fontSize: 15,
                color: _focused ? colors.primary : colors.textMuted,
              ),
              floatingLabelStyle: TextStyle(
                fontSize: 12,
                color: _focused ? colors.primary : colors.textMuted,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              suffixIcon: widget.obscureText
                  ? IconButton(
                      onPressed: () => setState(() => _obscured = !_obscured),
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                        color: colors.textMuted,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (!widget.isLast)
          Divider(
            height: 1,
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
            color: colors.divider,
          ),
      ],
    );
  }
}
