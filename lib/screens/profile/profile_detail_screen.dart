import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../components/app_avatar.dart';
import '../../components/app_card.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../l10n/app_tr.dart';
import 'account_store.dart';

const double _kPagePadding = 20.0;

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  String _name = '';
  String _login = '';

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final account = await AccountStore.load();
    if (!mounted) return;
    setState(() {
      _name = account.name;
      _login = account.login;
    });
  }

  Future<void> _openEdit() async {
    HapticFeedback.selectionClick();
    await context.push('/profile/settings');
    await _loadAccount();
  }

  void _copyLogin() {
    if (_login.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: _login));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Логин скопирован', 'Username copied')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sp = context.watch<SettingsProvider>();
    final settings = sp.settings;
    final name = _name.isNotEmpty ? _name : settings.ownerName.trim();
    final displayName =
        name.isNotEmpty ? name : context.tr('Мой профиль', 'My profile');
    final business = settings.businessName.trim();
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
                      context.tr('Данные аккаунта', 'Account details'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openEdit,
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
                          const Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('Изменить', 'Edit'),
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

            // ── 2. Content ─────────────────────────────────────────────────
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  _kPagePadding,
                  8,
                  _kPagePadding,
                  48,
                ),
                children: [
                  // Hero Summary Card
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        AppAvatar(name: displayName, size: 58),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                business.isNotEmpty
                                    ? business
                                    : context.tr(
                                        'Название бизнеса не указано',
                                        'Business name not set'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (_login.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _copyLogin,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.background,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.alternate_email_rounded,
                                          size: 12,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _login,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Icon(
                                          Icons.copy_rounded,
                                          size: 11,
                                          color: colors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Detailed Attributes Card
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _AccountDetailItem(
                          icon: Icons.person_outline_rounded,
                          label: context.tr('Имя владельца', 'Owner name'),
                          value: name,
                        ),
                        Divider(height: 1, indent: 56, color: colors.divider),
                        _AccountDetailItem(
                          icon: Icons.alternate_email_rounded,
                          label: context.tr('Логин для входа', 'Username'),
                          value: _login,
                        ),
                        Divider(height: 1, indent: 56, color: colors.divider),
                        _AccountDetailItem(
                          icon: Icons.storefront_outlined,
                          label:
                              context.tr('Название бизнеса', 'Business name'),
                          value: business,
                        ),
                        Divider(height: 1, indent: 56, color: colors.divider),
                        _AccountDetailItem(
                          icon: Icons.payments_outlined,
                          label:
                              context.tr('Основная валюта', 'Primary currency'),
                          value: settings.currency,
                        ),
                        Divider(height: 1, indent: 56, color: colors.divider),
                        _AccountDetailItem(
                          icon: Icons.language_rounded,
                          label: context.tr(
                              'Язык интерфейса', 'Interface language'),
                          value: settings.locale == 'ru' ? 'Русский' : 'English',
                        ),
                        Divider(height: 1, indent: 56, color: colors.divider),
                        _AccountDetailItem(
                          icon: Icons.category_outlined,
                          label: context.tr('Категории учёта', 'Categories'),
                          value: context.tr(
                              '$totalCategories (доходы: ${sp.incomeCategories.length}, расходы: ${sp.expenseCategories.length})',
                              '$totalCategories (income: ${sp.incomeCategories.length}, expense: ${sp.expenseCategories.length})'),
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
}

class _AccountDetailItem extends StatelessWidget {
  const _AccountDetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final empty = value.trim().isEmpty;

    return Padding(
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
            child: Icon(icon, size: 17, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  empty ? context.tr('Не указано', 'Not set') : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: empty ? colors.textMuted : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
