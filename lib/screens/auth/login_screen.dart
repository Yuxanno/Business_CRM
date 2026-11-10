import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../components/auth/auth_backdrop.dart';
import '../../components/auth/auth_header.dart';
import '../../components/app_button.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';
import '../../theme/app_spacing.dart';
import '../../providers/settings_provider.dart';
import '../profile/account_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _loginError;
  String? _passwordError;
  var _isLoading = false;
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    final login = _loginCtrl.text.trim();
    if (login.isEmpty || login.length < 3) {
      _loginError = 'Минимум 3 символа';
      valid = false;
    } else {
      _loginError = null;
    }
    if (_passwordCtrl.text.isEmpty || _passwordCtrl.text.length < 6) {
      _passwordError = 'Минимум 6 символов';
      valid = false;
    } else {
      _passwordError = null;
    }
    setState(() {});
    return valid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3001/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _loginCtrl.text.trim(),
          'password': _passwordCtrl.text,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', json['token']);
        await AccountStore.remember(
          name: (json['name'] ?? '').toString(),
          login: (json['username'] ?? '').toString(),
        );
        if (!mounted) return;
        
        // Sync all user data from server
        final business = (json['businessName'] ?? '').toString();
        final currency = (json['currency'] ?? 'RUB').toString();
        final locale = (json['locale'] ?? 'ru').toString();
        final settings = context.read<SettingsProvider>();
        await settings.update(
          settings.settings.copyWith(
            businessName: business.isNotEmpty ? business : settings.settings.businessName,
            ownerName: (json['name'] ?? '').toString(),
            currency: currency,
            locale: locale,
          ),
        );
        
        if (mounted) context.go('/home');
      } else {
        final json = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(json['error'] ?? 'Ошибка входа'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось подключиться к серверу'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackdrop(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthHeader(
                    title: 'Снова\nв деле',
                    subtitle: 'Войдите по логину и паролю — email не нужен',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SheetField(
                    label: 'Логин',
                    child: FormTextField(
                      controller: _loginCtrl,
                      hint: 'Минимум 3 символа',
                    ),
                  ),
                  if (_loginError != null) FormFieldError(text: _loginError!),
                  const SizedBox(height: AppSpacing.lg),
                  SheetField(
                    label: 'Пароль',
                    child: FormTextField(
                      controller: _passwordCtrl,
                      hint: 'Минимум 6 символов',
                      obscureText: true,
                    ),
                  ),
                  if (_passwordError != null) FormFieldError(text: _passwordError!),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Войти',
                    onPressed: _submit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Ещё нет аккаунта? Регистрация',
                    onPressed: () => context.go('/register'),
                    variant: AppButtonVariant.text,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
