import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../components/app_card.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';
import '../../l10n/app_tr.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  String _currency = 'UZS';
  String _locale = 'ru';

  @override
  void dispose() {
    _pageController.dispose();
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page == 0) return;
    HapticFeedback.selectionClick();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    final sp = context.read<SettingsProvider>();
    await sp.completeOnboarding(
      businessName: _businessNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      currency: _currency,
      locale: _locale,
      themeMode: 'light',
    );
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar & back control
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  if (_page > 0) ...[
                    GestureDetector(
                      onTap: _back,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Row(
                      children: List.generate(
                        3,
                        (i) => Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 4,
                            decoration: BoxDecoration(
                              color:
                                  i <= _page ? colors.primary : colors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _WelcomePage(onNext: _next),
                  _BusinessInfoPage(
                    businessNameCtrl: _businessNameCtrl,
                    ownerNameCtrl: _ownerNameCtrl,
                    onNext: _next,
                  ),
                  _PreferencesPage(
                    currency: _currency,
                    locale: _locale,
                    onCurrencyChanged: (v) => setState(() => _currency = v),
                    onLocaleChanged: (v) => setState(() => _locale = v),
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 1: Welcome ──────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Business CRM',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('Порядок\nв делах бизнеса', 'Clarity\nin your business'),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              height: 1.12,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'Учитывайте доходы, заказы, клиентов и долги в одном спокойном приложении.',
              'Track income, orders, customers, and debts in one calm workspace.',
            ),
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _FeatureItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: context.tr('Доходы и расходы', 'Income & expenses'),
                  subtitle: context.tr(
                    'Категории, графики и итоги за каждый месяц',
                    'Categories, charts, and monthly summaries',
                  ),
                ),
                Divider(height: 20, color: colors.divider),
                _FeatureItem(
                  icon: Icons.receipt_long_outlined,
                  title: context.tr('Заказы и клиенты', 'Orders & customers'),
                  subtitle: context.tr(
                    'Статусы выполнения, оплаты и база контактов',
                    'Order statuses, payments, and contact directory',
                  ),
                ),
                Divider(height: 20, color: colors.divider),
                _FeatureItem(
                  icon: Icons.handshake_outlined,
                  title: context.tr('Долги и расчёты', 'Debts & settlements'),
                  subtitle: context.tr(
                    'Контроль кто должен вам и кому должны вы',
                    'Track who owes you and whom you owe',
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FormSubmitButton(
            label: context.tr('Начать', 'Get started'),
            icon: Icons.arrow_forward_rounded,
            accentColor: colors.primary,
            isLoading: false,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
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
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Page 2: Business Info ────────────────────────────────────────────────────

class _BusinessInfoPage extends StatelessWidget {
  const _BusinessInfoPage({
    required this.businessNameCtrl,
    required this.ownerNameCtrl,
    required this.onNext,
  });

  final TextEditingController businessNameCtrl;
  final TextEditingController ownerNameCtrl;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('О вашем бизнесе', 'About your business'),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Необязательно — вы сможете изменить эти данные позже в настройках',
              'Optional — you can change these details later in settings',
            ),
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetField(
                  label: context.tr('ВАШЕ ИМЯ', 'YOUR NAME'),
                  child: FormTextField(
                    controller: ownerNameCtrl,
                    prefixIcon: Icons.person_outline_rounded,
                    hint: context.tr('Например: Иван', 'e.g. John'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(height: 16),
                SheetField(
                  label: context.tr('НАЗВАНИЕ БИЗНЕСА', 'BUSINESS NAME'),
                  child: FormTextField(
                    controller: businessNameCtrl,
                    prefixIcon: Icons.storefront_outlined,
                    hint: context.tr('Например: ИП Иванов', 'e.g. Acme Studio'),
                    textCapitalization: TextCapitalization.sentences,
                    onFieldSubmitted: (_) => onNext(),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FormSubmitButton(
            label: context.tr('Продолжить', 'Continue'),
            icon: Icons.arrow_forward_rounded,
            accentColor: colors.primary,
            isLoading: false,
            onPressed: onNext,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onNext,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: Text(
                context.tr('Пропустить', 'Skip'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 3: Preferences ──────────────────────────────────────────────────────

class _PreferencesPage extends StatelessWidget {
  const _PreferencesPage({
    required this.currency,
    required this.locale,
    required this.onCurrencyChanged,
    required this.onLocaleChanged,
    required this.onFinish,
  });

  final String currency;
  final String locale;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onLocaleChanged;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Валюта и язык', 'Currency & language'),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Основная валюта используется во всех операциях, заказах и отчётах.',
              'Primary currency is used across all transactions, orders, and reports.',
            ),
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OptionRow(
                  label: context.tr('ОСНОВНАЯ ВАЛЮТА', 'PRIMARY CURRENCY'),
                  options: const ['UZS', 'RUB', 'USD', 'EUR', 'KZT'],
                  selected: currency,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    onCurrencyChanged(v);
                  },
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: colors.divider),
                const SizedBox(height: 20),
                _OptionRow(
                  label: context.tr('ЯЗЫК ИНТЕРФЕЙСА', 'INTERFACE LANGUAGE'),
                  options: const ['ru', 'en'],
                  labels: const ['Русский', 'English'],
                  selected: locale,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    onLocaleChanged(v);
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          FormSubmitButton(
            label: context.tr('Готово', 'Done'),
            icon: Icons.check_rounded,
            accentColor: colors.primary,
            isLoading: false,
            onPressed: onFinish,
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.options,
    this.labels,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final List<String>? labels;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.asMap().entries.map((e) {
            final opt = e.value;
            final lbl = labels?[e.key] ?? opt;
            final isSelected = selected == opt;
            return GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                  ),
                ),
                child: Text(
                  lbl,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : colors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
