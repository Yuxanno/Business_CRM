import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/auth/auth_backdrop.dart';
import '../../components/auth/auth_header.dart';
import '../../components/form_widgets.dart';
import '../../l10n/app_tr.dart';
import '../../theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../profile/account_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialRegister = false});

  final bool initialRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();

  late final AnimationController _modeCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _modeCurve;
  late final Animation<double> _fieldFade;
  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  late bool _isRegister;
  int _registerStep = 0;
  String _currency = 'UZS';
  String? _nameError;
  String? _loginError;
  String? _passwordError;
  String? _confirmError;
  var _isLoading = false;
  var _authSuccess = false;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.initialRegister;
    _modeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: _isRegister ? 1.0 : 0.0,
    );
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..forward();
    _enterFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOutCubic,
    );
    _enterSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOutCubic,
    ));
    _modeCurve = CurvedAnimation(
      parent: _modeCtrl,
      curve: Curves.easeInOutCubic,
    );
    _fieldFade = CurvedAnimation(
      parent: _modeCtrl,
      curve: const Interval(0.22, 1.0, curve: Curves.easeOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          NotificationService.instance.promptPermissionIfNeeded(context);
        }
      });
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _modeCtrl.dispose();
    _nameCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _businessNameCtrl.dispose();
    super.dispose();
  }

  void _setMode(bool register) {
    if (_isRegister == register || _isLoading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isRegister = register;
      _registerStep = 0;
      _nameError = null;
      _loginError = null;
      _passwordError = null;
      _confirmError = null;
    });
    if (register) {
      _modeCtrl.forward();
    } else {
      _modeCtrl.reverse();
    }
  }

  void _nextRegisterStep() {
    if (_isLoading || !_validate()) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() => _registerStep = 1);
  }

  bool _validate() {
    bool valid = true;

    if (_isRegister) {
      if (_nameCtrl.text.trim().length < 2) {
        _nameError = context.tr('Минимум 2 символа', 'Minimum 2 characters');
        valid = false;
      } else {
        _nameError = null;
      }
    } else {
      _nameError = null;
    }

    final login = _loginCtrl.text.trim();
    if (_isRegister) {
      final loginOk = RegExp(r'^[a-zA-Z0-9._-]{3,32}$').hasMatch(login);
      if (!loginOk) {
        _loginError = context.tr(
          '3–32 символа: латиница, цифры, . _ -',
          '3–32 chars: letters, digits, . _ -',
        );
        valid = false;
      } else {
        _loginError = null;
      }
    } else {
      if (login.isEmpty || login.length < 3) {
        _loginError = context.tr('Минимум 3 символа', 'Minimum 3 characters');
        valid = false;
      } else {
        _loginError = null;
      }
    }

    if (_passwordCtrl.text.isEmpty || _passwordCtrl.text.length < 6) {
      _passwordError = context.tr('Минимум 6 символов', 'Minimum 6 characters');
      valid = false;
    } else {
      _passwordError = null;
    }

    if (_isRegister) {
      if (_confirmCtrl.text.isEmpty ||
          _confirmCtrl.text != _passwordCtrl.text) {
        _confirmError =
            context.tr('Пароли не совпадают', 'Passwords do not match');
        valid = false;
      } else {
        _confirmError = null;
      }
    } else {
      _confirmError = null;
    }

    setState(() {});
    return valid;
  }

  Future<void> _submit() async {
    if (_isLoading || !_validate()) return;

    setState(() => _isLoading = true);

    try {
      final endpoint = _isRegister ? '/api/auth/register' : '/api/auth/login';
      final selectedLocale = context.read<SettingsProvider>().locale;
      final body = _isRegister
          ? {
              'name': _nameCtrl.text.trim(),
              'username': _loginCtrl.text.trim(),
              'password': _passwordCtrl.text,
              'businessName': _businessNameCtrl.text.trim(),
              'currency': _currency,
              'locale': selectedLocale,
            }
          : {
              'username': _loginCtrl.text.trim(),
              'password': _passwordCtrl.text,
            };

      final raw = await ApiClient.instance.post(endpoint, body);
      final json = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      final prefs = await SharedPreferences.getInstance();
      final token = (json['token'] ?? '').toString();
      await prefs.setString('authToken', token);
      ApiClient.instance.setToken(token);
      await AccountStore.remember(
        name: (json['name'] ?? '').toString(),
        login: (json['username'] ?? '').toString(),
      );
      if (!mounted) return;

      final business = (_isRegister
              ? _businessNameCtrl.text.trim()
              : (json['businessName'] ?? '').toString())
          .trim();
      final currency = (_isRegister
              ? _currency
              : (json['currency'] ?? 'UZS').toString())
          .trim();
      final settings = context.read<SettingsProvider>();
      final locale = (json['locale'] ?? settings.locale).toString();

      await settings.update(
        settings.settings.copyWith(
          businessName: business,
          ownerName: (json['name'] ?? '').toString(),
          currency: currency,
          locale: locale,
          isOnboardingDone: true,
        ),
      );

      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _authSuccess = true;
          _isLoading = false;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 560));
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _authSuccess = false;
        });
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _authSuccess = false;
        });
        _showError(
          context.tr(
            'Не удалось подключиться к серверу',
            'Could not connect to server',
          ),
        );
      }
    }
  }

  void _showError(String message) {
    final colors = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.expense,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final topPad = (MediaQuery.sizeOf(context).height * 0.06).clamp(22.0, 52.0);
    final isEn = context.isEn;

    return AuthBackdrop(
      child: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, topPad, 20, 32),
                child: FadeTransition(
                  opacity: _enterFade,
                  child: SlideTransition(
                    position: _enterSlide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthHeader(
                          titleTop: _isRegister
                              ? context.tr('Новый', 'Create')
                              : context.tr('Снова', 'Welcome'),
                          titleAccent: _isRegister
                              ? context.tr('аккаунт', 'account')
                              : context.tr('в деле', 'back'),
                          subtitle: _isRegister
                              ? context.tr(
                                  'Быстрый старт за 30 секунд — без почты и подтверждений',
                                  'Quick 30-second start — no email or verification needed',
                                )
                              : context.tr(
                                  'Войдите по логину и паролю — почта и лишние шаги не нужны',
                                  'Sign in with username and password — no extra steps',
                                ),
                        ),

                  const SizedBox(height: 22),

                  // Sliding black-pill mode switch (Вход / Регистрация)
                  _AuthModeSwitch(
                    isLogin: !_isRegister,
                    onSelectLogin: () => _setMode(false),
                    onSelectRegister: () => _setMode(true),
                  ),

                  const SizedBox(height: 16),

                  // Elevated architectural form surface
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.85),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.06),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Subtle top accent strip
                        Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 28),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.ink],
                            ),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(4),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: (_isRegister && _registerStep == 1)
                                  ? _buildRegisterProfileStep(context, isEn)
                                  : Column(
                                      key: const ValueKey('auth_step_0'),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _CollapsibleAuthField(
                                          sizeAnim: _modeCurve,
                                          fadeAnim: _fieldFade,
                                          enabled: _isRegister,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              SheetField(
                                                label: context.tr(
                                                    'ИМЯ', 'NAME'),
                                                required: true,
                                                child: FormTextField(
                                                  controller: _nameCtrl,
                                                  prefixIcon: Icons
                                                      .person_outline_rounded,
                                                  hint: context.tr(
                                                    'Например: Иван',
                                                    'e.g. John Doe',
                                                  ),
                                                  textCapitalization:
                                                      TextCapitalization.words,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                ),
                                              ),
                                              if (_nameError != null)
                                                FormFieldError(
                                                    text: _nameError!),
                                              const SizedBox(height: 14),
                                            ],
                                          ),
                                        ),
                                        SheetField(
                                          label: context.tr(
                                              'ЛОГИН', 'USERNAME'),
                                          required: true,
                                          child: FormTextField(
                                            controller: _loginCtrl,
                                            prefixIcon:
                                                Icons.alternate_email_rounded,
                                            hint: _isRegister
                                                ? context.tr(
                                                    'Латиница, цифры, . _ -',
                                                    'Letters, digits, . _ -',
                                                  )
                                                : context.tr(
                                                    'Минимум 3 символа',
                                                    'Minimum 3 characters',
                                                  ),
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                        ),
                                        if (_loginError != null)
                                          FormFieldError(text: _loginError!),
                                        const SizedBox(height: 14),
                                        SheetField(
                                          label: context.tr(
                                              'ПАРОЛЬ', 'PASSWORD'),
                                          required: true,
                                          child: FormTextField(
                                            controller: _passwordCtrl,
                                            prefixIcon:
                                                Icons.lock_outline_rounded,
                                            hint: context.tr(
                                              'Минимум 6 символов',
                                              'Minimum 6 characters',
                                            ),
                                            obscureText: true,
                                            textInputAction: _isRegister
                                                ? TextInputAction.next
                                                : TextInputAction.done,
                                            onFieldSubmitted: _isRegister
                                                ? null
                                                : (_) => _submit(),
                                          ),
                                        ),
                                        if (_passwordError != null)
                                          FormFieldError(
                                              text: _passwordError!),
                                        _CollapsibleAuthField(
                                          sizeAnim: _modeCurve,
                                          fadeAnim: _fieldFade,
                                          enabled: _isRegister,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const SizedBox(height: 14),
                                              SheetField(
                                                label: context.tr(
                                                  'ПОДТВЕРДИТЕ ПАРОЛЬ',
                                                  'CONFIRM PASSWORD',
                                                ),
                                                required: true,
                                                child: FormTextField(
                                                  controller: _confirmCtrl,
                                                  prefixIcon: Icons
                                                      .verified_user_outlined,
                                                  hint: context.tr(
                                                    'Повторите пароль',
                                                    'Repeat password',
                                                  ),
                                                  obscureText: true,
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  onFieldSubmitted: (_) =>
                                                      _nextRegisterStep(),
                                                ),
                                              ),
                                              if (_confirmError != null)
                                                FormFieldError(
                                                    text: _confirmError!),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 22),
                                        _SignatureAuthButton(
                                          label: _isRegister
                                              ? context.tr(
                                                  'Продолжить',
                                                  'Continue',
                                                )
                                              : context.tr(
                                                  'Войти в кабинет',
                                                  'Sign in',
                                                ),
                                          icon: Icons.arrow_forward_rounded,
                                          isLoading: _isLoading,
                                          onPressed: _isRegister
                                              ? _nextRegisterStep
                                              : _submit,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.tr(
                            'Ваши финансы и база клиентов под защитой',
                            'Your finances and customer base are protected',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
            ),
          ),
            Positioned(
              top: 54,
              right: 20,
              child: _AuthLanguageButton(
                isEn: isEn,
                onToggle: () {
                  HapticFeedback.selectionClick();
                  context
                      .read<SettingsProvider>()
                      .setLocale(isEn ? 'ru' : 'en');
                },
              ),
            ),
            if (_isLoading || _authSuccess)
              _AuthTransitionOverlay(
                isRegister: _isRegister,
                isSuccess: _authSuccess,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterProfileStep(BuildContext context, bool isEn) {
    final colors = context.appColors;
    const currencies = [
      ('UZS', 'сўм'),
      ('RUB', '₽'),
      ('USD', '\$'),
      ('EUR', '€'),
      ('KZT', '₸'),
      ('GBP', '£'),
    ];
    const locales = [
      ('ru', 'RU', 'Русский'),
      ('en', 'EN', 'English'),
    ];

    return Column(
      key: const ValueKey('auth_step_1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() => _registerStep = 0);
                    },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 15,
                      color: colors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('Назад', 'Back'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                context.tr('Шаг 2 из 2', 'Step 2 of 2'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SheetField(
          label: context.tr('НАЗВАНИЕ БИЗНЕСА', 'BUSINESS NAME'),
          child: FormTextField(
            controller: _businessNameCtrl,
            prefixIcon: Icons.storefront_outlined,
            hint: context.tr(
              'Например: Студия дизайна',
              'e.g. Design Studio',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        const SizedBox(height: 16),
        SheetField(
          label: context.tr('ОСНОВНАЯ ВАЛЮТА', 'PRIMARY CURRENCY'),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currencies.map((c) {
              final selected = _currency == c.$1;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _currency = c.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary
                        : colors.surfaceSecondary.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? colors.primary : colors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.$1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        c.$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.85)
                              : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SheetField(
          label: context.tr('ЯЗЫК ИНТЕРФЕЙСА', 'INTERFACE LANGUAGE'),
          child: Row(
            children: locales.asMap().entries.map((entry) {
              final i = entry.key;
              final l = entry.value;
              final selected = (isEn ? 'en' : 'ru') == l.$1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.read<SettingsProvider>().setLocale(l.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary.withValues(alpha: 0.1)
                            : colors.surfaceSecondary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? colors.primary : colors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  selected ? colors.primary : colors.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l.$2,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? Colors.white
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            l.$3,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? colors.primary
                                  : colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 22),
        _SignatureAuthButton(
          label: context.tr('Создать аккаунт', 'Create account'),
          icon: Icons.check_rounded,
          isLoading: _isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _CollapsibleAuthField extends StatelessWidget {
  const _CollapsibleAuthField({
    required this.sizeAnim,
    required this.fadeAnim,
    required this.enabled,
    required this.child,
  });

  final Animation<double> sizeAnim;
  final Animation<double> fadeAnim;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: sizeAnim,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: fadeAnim,
        child: IgnorePointer(
          ignoring: !enabled,
          child: ExcludeFocus(
            excluding: !enabled,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Segmented switch where only the dark indicator pill slides left <-> right.
class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.isLogin,
    required this.onSelectLogin,
    required this.onSelectRegister,
  });

  final bool isLogin;
  final VoidCallback onSelectLogin;
  final VoidCallback onSelectRegister;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment:
                isLogin ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onSelectLogin,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 160),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isLogin ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isLogin ? Colors.white : colors.textSecondary,
                      ),
                      child: Text(context.tr('Вход', 'Sign in')),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onSelectRegister,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 160),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            !isLogin ? FontWeight.w700 : FontWeight.w600,
                        color:
                            !isLogin ? Colors.white : colors.textSecondary,
                      ),
                      child: Text(context.tr('Регистрация', 'Sign up')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthLanguageButton extends StatelessWidget {
  const _AuthLanguageButton({
    required this.isEn,
    required this.onToggle,
  });

  final bool isEn;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language_rounded,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                isEn ? 'EN' : 'RU',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignatureAuthButton extends StatefulWidget {
  const _SignatureAuthButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  State<_SignatureAuthButton> createState() => _SignatureAuthButtonState();
}

class _SignatureAuthButtonState extends State<_SignatureAuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.isLoading ? null : (_) => setState(() => _pressed = true),
      onTapUp:
          widget.isLoading ? null : (_) => setState(() => _pressed = false),
      onTapCancel:
          widget.isLoading ? null : () => setState(() => _pressed = false),
      onTap: widget.isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onPressed();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.ink, Color(0xFF0D4E54)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : Row(
                  children: [
                    const SizedBox(width: 34),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Text(
                          widget.label,
                          key: ValueKey(widget.label),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AuthTransitionOverlay extends StatelessWidget {
  const _AuthTransitionOverlay({
    required this.isRegister,
    required this.isSuccess,
  });

  final bool isRegister;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final label = isSuccess
        ? (isRegister
            ? context.tr('Аккаунт создан!', 'Account created!')
            : context.tr('Добро пожаловать!', 'Welcome back!'))
        : (isRegister
            ? context.tr('Создаём аккаунт...', 'Creating account...')
            : context.tr('Вход в BizFlow...', 'Signing in...'));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, fade, child) => Opacity(
        opacity: fade,
        child: child,
      ),
      child: Positioned.fill(
        child: ColoredBox(
          color: colors.background.withValues(alpha: 0.88),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.92, end: 1.0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Container(
                width: 240,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: isSuccess
                          ? Container(
                              key: const ValueKey('auth-ok'),
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: colors.income,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.income.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('auth-loading'),
                              width: 62,
                              height: 62,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 62,
                                    height: 62,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: colors.primary,
                                      backgroundColor: colors.border,
                                    ),
                                  ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      width: 42,
                                      height: 42,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        label,
                        key: ValueKey(label),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
