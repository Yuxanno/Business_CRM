import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/settings_provider.dart';
import '../../components/app_card.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';
import '../../l10n/app_tr.dart';
import '../profile/account_store.dart';

const double _kPagePadding = 20.0;

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
    final settings = context.read<SettingsProvider>().settings;
    _nameCtrl.text = settings.ownerName;
    _businessNameCtrl.text = settings.businessName;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsProvider>().reload();
    });

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
      final sp = context.read<SettingsProvider>();
      if (account.currency != null || account.locale != null) {
        sp.update(
          sp.settings.copyWith(
            currency: account.currency ?? sp.settings.currency,
            locale: account.locale ?? sp.settings.locale,
            businessName: account.businessName.isNotEmpty
                ? account.businessName
                : sp.settings.businessName,
            ownerName: account.name.isNotEmpty
                ? account.name
                : sp.settings.ownerName,
          ),
        );
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
      _toast(context.tr('Укажите имя пользователя', 'Enter owner name'));
      return;
    }
    if (login.isNotEmpty &&
        !RegExp(r'^[a-zA-Z0-9._-]{3,32}$').hasMatch(login)) {
      _toast(context.tr(
          'Логин: 3–32 символа, латиница, цифры, . _ -',
          'Username: 3–32 chars, letters, digits, . _ -'));
      return;
    }
    if (password.isNotEmpty && password.length < 6) {
      _toast(context.tr('Новый пароль — минимум 6 символов',
          'New password must be at least 6 chars'));
      return;
    }

    setState(() => _saving = true);
    try {
      final sp = context.read<SettingsProvider>();
      if (login.isNotEmpty) {
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
      }

      await sp.update(
        sp.settings.copyWith(
          businessName: business,
          ownerName: name,
        ),
      );
      _passwordCtrl.clear();
      HapticFeedback.mediumImpact();
      if (mounted) {
        FocusScope.of(context).unfocus();
        _toast(context.tr('Изменения сохранены', 'Changes saved'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sp = context.watch<SettingsProvider>();
    final settings = sp.settings;
    final totalCategories =
        sp.incomeCategories.length + sp.expenseCategories.length;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Clean Top Bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.md,
                _kPagePadding,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/profile');
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('Настройки', 'Settings'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _saving ? null : _saveProfile,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_saving)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            _saving
                                ? context.tr('Сохранение...', 'Saving...')
                                : context.tr('Сохранить', 'Save'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. Scrollable Content ──────────────────────────────────────
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  _kPagePadding,
                  8,
                  _kPagePadding,
                  60,
                ),
                children: [
                  _SettingsSectionTitle(
                      context.tr('Профиль и бизнес', 'Profile & business')),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SheetField(
                          label: context.tr('ИМЯ ВЛАДЕЛЬЦА', 'OWNER NAME'),
                          required: true,
                          child: FormTextField(
                            controller: _nameCtrl,
                            prefixIcon: Icons.person_outline_rounded,
                            hint: context.tr('Как к вам обращаться...',
                                'How should we address you...'),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SheetField(
                          label:
                              context.tr('НАЗВАНИЕ БИЗНЕСА', 'BUSINESS NAME'),
                          child: FormTextField(
                            controller: _businessNameCtrl,
                            prefixIcon: Icons.storefront_outlined,
                            hint: context.tr('Название компании или проекта...',
                                'Company or project name...'),
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SheetField(
                          label: context.tr('ЛОГИН АККАУНТА', 'USERNAME'),
                          child: FormTextField(
                            controller: _loginCtrl,
                            prefixIcon: Icons.alternate_email_rounded,
                            hint: context.tr(
                                'Логин для входа...', 'Sign-in username...'),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SheetField(
                          label: context.tr('НОВЫЙ ПАРОЛЬ', 'NEW PASSWORD'),
                          child: FormTextField(
                            controller: _passwordCtrl,
                            prefixIcon: Icons.lock_outline_rounded,
                            hint: context.tr('Оставьте пустым, если не меняете',
                                'Leave blank to keep current'),
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _saveProfile(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FormSubmitButton(
                          label:
                              context.tr('Сохранить профиль', 'Save profile'),
                          icon: Icons.check_rounded,
                          accentColor: colors.primary,
                          isLoading: _saving,
                          onPressed: _saveProfile,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  _SettingsSectionTitle(
                      context.tr('Учёт и интерфейс', 'Accounting & interface')),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ModernPreferenceRow(
                          icon: Icons.payments_outlined,
                          title:
                              context.tr('Основная валюта', 'Primary currency'),
                          subtitle: context.tr(
                              'Используется в операциях, заказах и долгах',
                              'Used in transactions, orders, and debts'),
                          valueBadge: settings.currency,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showCurrencyPicker(context);
                          },
                        ),
                        Divider(height: 1, indent: 56, color: colors.divider),
                        _ModernPreferenceRow(
                          icon: Icons.language_rounded,
                          title: context.tr(
                              'Язык интерфейса', 'Interface language'),
                          subtitle: context.tr('Язык отображения приложения',
                              'App display language'),
                          valueBadge:
                              settings.locale == 'ru' ? 'Русский' : 'English',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showLocalePicker(context);
                          },
                        ),
                        Divider(height: 1, indent: 56, color: colors.divider),
                        _ModernPreferenceRow(
                          icon: Icons.category_outlined,
                          title: context.tr('Категории доходов и расходов',
                              'Income & expense categories'),
                          subtitle: context.tr(
                              'Добавление, переименование и удаление',
                              'Add, rename, and remove categories'),
                          valueBadge: '$totalCategories',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/profile/categories');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    final colors = context.appColors;
    final currencies = [
      ('UZS', 'сўм', context.tr('Узбекский сум', 'Uzbekistani som')),
      ('RUB', '₽', context.tr('Российский рубль', 'Russian ruble')),
      ('USD', '\$', context.tr('Доллар США', 'US dollar')),
      ('EUR', '€', context.tr('Евро', 'Euro')),
      ('KZT', '₸', context.tr('Казахстанский тенге', 'Kazakhstani tenge')),
      ('GBP', '£', context.tr('Фунт стерлингов', 'British pound')),
    ];

    showAppModal(
      context: context,
      child: Builder(
        builder: (modalCtx) {
          final current = context.read<SettingsProvider>().currency;
          return AppModalSheet(
            title: context.tr('Основная валюта', 'Primary currency'),
            subtitle: context.tr(
                'Используется во всех расчётах, заказах и отчётах',
                'Used in all calculations, orders, and reports'),
            headerIcon: Icons.currency_exchange_rounded,
            headerColor: colors.primary,
            maxHeightFactor: 0.75,
            body: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              itemCount: currencies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = currencies[i];
                final isSelected = current == c.$1;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(modalCtx).pop();
                    context.read<SettingsProvider>().setCurrency(c.$1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary.withValues(alpha: 0.08)
                          : colors.surfaceSecondary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? colors.primary : colors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary : colors.surface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color:
                                  isSelected ? colors.primary : colors.border,
                            ),
                          ),
                          child: Text(
                            c.$1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.$3,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                context.tr(
                                    'Символ: ${c.$2}', 'Symbol: ${c.$2}'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? colors.primary : colors.border,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showLocalePicker(BuildContext context) {
    final colors = context.appColors;
    final locales = [
      (
        'ru',
        'RU',
        'Русский',
        context.tr('Основной язык интерфейса', 'Russian interface')
      ),
      ('en', 'EN', 'English', 'Interface language'),
    ];

    showAppModal(
      context: context,
      child: Builder(
        builder: (modalCtx) {
          final current = context.read<SettingsProvider>().locale;
          return AppModalSheet(
            title: context.tr('Язык интерфейса', 'Interface language'),
            subtitle: context.tr('Выберите язык отображения приложения',
                'Choose app display language'),
            headerIcon: Icons.language_rounded,
            headerColor: colors.primary,
            body: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              itemCount: locales.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final l = locales[i];
                final isSelected = current == l.$1;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(modalCtx).pop();
                    context.read<SettingsProvider>().setLocale(l.$1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary.withValues(alpha: 0.08)
                          : colors.surfaceSecondary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? colors.primary : colors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary : colors.surface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color:
                                  isSelected ? colors.primary : colors.border,
                            ),
                          ),
                          child: Text(
                            l.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.$3,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                l.$4,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? colors.primary : colors.border,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: colors.textSecondary,
      ),
    );
  }
}

class _ModernPreferenceRow extends StatelessWidget {
  const _ModernPreferenceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueBadge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String valueBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Icon(icon, size: 18, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                valueBadge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// Kept for hot-reload compatibility
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}

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
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
