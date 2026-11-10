import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../components/app_button.dart';
import '../../components/app_card.dart';
import '../../components/app_templates.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'account_store.dart';

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
    AccountStore.load().then((account) {
      if (!mounted) return;
      setState(() {
        _name = account.name;
        _login = account.login;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = context.watch<SettingsProvider>().settings;
    final name = _name.isNotEmpty ? _name : settings.ownerName;
    final business = settings.businessName;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 32),
          children: [
            const AppPageTitle(
              title: 'Мой профиль',
              subtitle: 'Имя, логин и данные бизнеса',
              showBack: true,
              fallbackRoute: '/profile',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _DetailRow(label: 'Имя', value: name),
                  Divider(height: 1, color: colors.divider),
                  _DetailRow(label: 'Логин', value: _login),
                  Divider(height: 1, color: colors.divider),
                  _DetailRow(label: 'Бизнес', value: business),
                  Divider(height: 1, color: colors.divider),
                  _DetailRow(label: 'Валюта', value: settings.currency),
                  Divider(height: 1, color: colors.divider),
                  _DetailRow(
                    label: 'Язык',
                    value: settings.locale == 'ru' ? 'Русский' : 'English',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: name.isEmpty || business.isEmpty
                  ? 'Добавить данные'
                  : 'Изменить',
              onPressed: () async {
                await context.push('/profile/settings');
                final account = await AccountStore.load();
                if (!mounted) return;
                setState(() {
                  _name = account.name;
                  _login = account.login;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final empty = value.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              empty ? 'Не указано' : value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: empty ? colors.textMuted : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
