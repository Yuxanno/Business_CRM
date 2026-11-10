import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/settings_provider.dart';
import '../../components/app_button.dart';

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
  String _currency = 'RUB';
  String _locale = 'ru';

  @override
  void dispose() {
    _pageController.dispose();
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
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
            // Progress dots
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= _page ? colors.primary : colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Icon(Icons.business_center_rounded,
                size: 32, color: colors.primary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Добро\nпожаловать',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Business Manager поможет вам управлять заказами, клиентами и финансами бизнеса.',
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary,
              height: 1.6,
            ),
          ),
          const Spacer(),
          AppButton(label: 'Начать', onPressed: onNext),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text('О вашем бизнесе',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Необязательно — можно заполнить позже',
              style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          const SizedBox(height: AppSpacing.xxxl),
          _buildField(context, 'Ваше имя', 'Например: Иван', ownerNameCtrl),
          const SizedBox(height: AppSpacing.lg),
          _buildField(context, 'Название бизнеса', 'Например: ИП Иванов',
              businessNameCtrl),
          const Spacer(),
          AppButton(label: 'Продолжить', onPressed: onNext),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Пропустить',
            onPressed: onNext,
            variant: AppButtonVariant.text,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, String label, String hint,
      TextEditingController ctrl) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: ctrl,
          style: TextStyle(fontSize: 15, color: colors.textPrimary),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text('Настройки',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Валюта появится рядом с суммами. Язык меняет подписи интерфейса.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _OptionRow(
            label: 'Валюта',
            options: const ['RUB', 'USD', 'EUR', 'KZT'],
            selected: currency,
            onChanged: onCurrencyChanged,
          ),
          const SizedBox(height: AppSpacing.xl),
          _OptionRow(
            label: 'Язык',
            options: const ['ru', 'en'],
            labels: const ['Русский', 'English'],
            selected: locale,
            onChanged: onLocaleChanged,
          ),
          const Spacer(),
          AppButton(label: 'Готово', onPressed: onFinish),
          const SizedBox(height: AppSpacing.lg),
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
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: options.asMap().entries.map((e) {
            final opt = e.value;
            final lbl = labels?[e.key] ?? opt;
            final isSelected = selected == opt;
            return GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                  ),
                ),
                child: Text(
                  lbl,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? colors.onPrimary : colors.textSecondary,
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
