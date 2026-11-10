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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _nameError;
  String? _loginError;
  String? _passwordError;
  String? _confirmError;
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
    _nameCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    if (_nameCtrl.text.trim().length < 2) {
      _nameError = 'Минимум 2 символа';
      valid = false;
    } else {
      _nameError = null;
    }

    final login = _loginCtrl.text.trim();
    final loginOk = RegExp(r'^[a-zA-Z0-9._-]{3,32}$').hasMatch(login);
    if (!loginOk) {
      _loginError = '3–32 символа: латиница, цифры, . _ -';
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

    if (_confirmCtrl.text.isEmpty ||
        _confirmCtrl.text != _passwordCtrl.text) {
      _confirmError = 'Пароли не совпадают';
      valid = false;
    } else {
      _confirmError = null;
    }

    setState(() {});
    return valid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3001/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameCtrl.text.trim(),
          'username': _loginCtrl.text.trim(),
          'password': _passwordCtrl.text,
        }),
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', json['token']);
        await AccountStore.remember(
          name: (json['name'] ?? '').toString(),
          login: (json['username'] ?? '').toString(),
        );
        
        // Sync currency and locale from server
        if (mounted) {
          final currency = (json['currency'] ?? 'RUB').toString();
          final locale = (json['locale'] ?? 'ru').toString();
          final settings = context.read<SettingsProvider>();
          await settings.update(
            settings.settings.copyWith(
              currency: currency,
              locale: locale,
            ),
          );
        }
        
        if (mounted) context.go('/home');
      } else {
        final json = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(json['error'] ?? 'Ошибка регистрации'),
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
                    title: 'Новый\nаккаунт',
                    subtitle:
                        'Только логин и пароль — без почты и лишних шагов',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SheetField(
                    label: 'Имя',
                    child: FormTextField(
                      controller: _nameCtrl,
                      hint: 'Например: Иван',
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  if (_nameError != null) FormFieldError(text: _nameError!),
                  const SizedBox(height: AppSpacing.lg),
                  SheetField(
                    label: 'Логин',
                    child: FormTextField(
                      controller: _loginCtrl,
                      hint: 'Латиница, цифры, точка, _ или -',
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
                  const SizedBox(height: AppSpacing.lg),
                  SheetField(
                    label: 'Подтвердите пароль',
                    child: FormTextField(
                      controller: _confirmCtrl,
                      hint: 'Повторите пароль',
                      obscureText: true,
                    ),
                  ),
                  if (_confirmError != null) FormFieldError(text: _confirmError!),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Создать аккаунт',
                    onPressed: _submit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Уже есть аккаунт? Войти',
                    onPressed: () => context.go('/login'),
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
