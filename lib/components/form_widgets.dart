/// Shared modern form widgets used across all modal form sheets.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_tr.dart';
import '../providers/settings_provider.dart';
import '../services/financial_calculator.dart';
import '../services/date_helper.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// ─── Amount input ─────────────────────────────────────────────────────────────

/// Formats numeric money input with spaces as thousand separators
/// (e.g. `1000` → `1 000`, `1000000` → `1 000 000`) while preserving cursor position.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  /// Formats an arbitrary numeric string into space-grouped form.
  static String formatString(String raw) {
    if (raw.isEmpty) return '';

    final buffer = StringBuffer();
    String? decimalSep;
    var seenDecimal = false;

    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      final code = ch.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        buffer.write(ch);
      } else if ((ch == '.' || ch == ',') && !seenDecimal) {
        seenDecimal = true;
        decimalSep = ch;
        buffer.write(ch);
      }
    }

    final clean = buffer.toString();
    if (clean.isEmpty) return '';

    String intPart;
    var fracPart = '';
    if (decimalSep != null) {
      final sepIdx = clean.indexOf(decimalSep);
      intPart = clean.substring(0, sepIdx);
      fracPart = clean.substring(sepIdx + 1);
      if (fracPart.length > 2) {
        fracPart = fracPart.substring(0, 2);
      }
    } else {
      intPart = clean;
    }

    if (intPart.isEmpty && decimalSep != null) {
      intPart = '0';
    } else if (intPart.length > 1) {
      intPart = intPart.replaceFirst(RegExp(r'^0+'), '');
      if (intPart.isEmpty) intPart = '0';
    }

    final grouped = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        grouped.write(' ');
      }
      grouped.write(intPart[i]);
      count++;
    }
    final formattedInt = grouped.toString().split('').reversed.join('');

    if (decimalSep != null) {
      return '$formattedInt$decimalSep$fracPart';
    }
    return formattedInt;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var workingText = newValue.text;
    var workingOffset =
        newValue.selection.extentOffset.clamp(0, workingText.length);

    // If the user backspaced a space separator, delete the preceding digit too
    // so backspacing never gets stuck on an auto-inserted space.
    if (oldValue.text.length - newValue.text.length == 1 &&
        workingOffset > 0 &&
        workingOffset < oldValue.text.length &&
        oldValue.text[workingOffset] == ' ') {
      workingText = workingText.substring(0, workingOffset - 1) +
          workingText.substring(workingOffset);
      workingOffset -= 1;
    }

    var nonSpaceBeforeCursor = 0;
    var seenDecimalBeforeCursor = false;
    for (var i = 0; i < workingOffset; i++) {
      final ch = workingText[i];
      final code = ch.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        nonSpaceBeforeCursor++;
      } else if ((ch == '.' || ch == ',') && !seenDecimalBeforeCursor) {
        seenDecimalBeforeCursor = true;
        nonSpaceBeforeCursor++;
      }
    }

    if ((workingText.startsWith('.') || workingText.startsWith(',')) &&
        workingOffset > 0) {
      nonSpaceBeforeCursor++;
    }

    final formatted = formatString(workingText);
    if (formatted.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    var targetOffset = 0;
    var counted = 0;
    while (targetOffset < formatted.length && counted < nonSpaceBeforeCursor) {
      if (formatted[targetOffset] != ' ') {
        counted++;
      }
      targetOffset++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: targetOffset),
    );
  }
}

/// Modern fintech amount field with sign badge, large tabular numbers,
/// currency badge, and inline validation state.
class FormAmountField extends StatefulWidget {
  const FormAmountField({
    super.key,
    required this.controller,
    required this.accentColor,
    required this.prefix,
    this.currency,
    this.autofocus = false,
    this.quickAmounts,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final Color accentColor;
  final String prefix;
  final String? currency;
  final bool autofocus;
  final List<int>? quickAmounts;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<FormAmountField> createState() => _FormAmountFieldState();
}

class _FormAmountFieldState extends State<FormAmountField> {
  bool _focused = false;
  bool _hasText = false;
  bool _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _syncFormattedController();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  void _syncFormattedController() {
    final current = widget.controller.text;
    final formatted = ThousandsSeparatorInputFormatter.formatString(current);
    if (current != formatted) {
      _isFormatting = true;
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isFormatting = false;
    }
  }

  void _onTextChanged() {
    if (_isFormatting) return;
    _syncFormattedController();
    final nowHas = widget.controller.text.isNotEmpty;
    if (nowHas != _hasText && mounted) {
      setState(() => _hasText = nowHas);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedCurrency =
        widget.currency ?? context.watch<SettingsProvider>().currency;
    final isSignPrefix =
        widget.prefix == '+' || widget.prefix == '−' || widget.prefix == '-';

    return FormField<String>(
      initialValue: widget.controller.text,
      validator: (_) {
        final v = widget.controller.text;
        if (v.trim().isEmpty) return context.tr('Введите сумму', 'Enter amount');
        final c = FinancialCalculator.parseAmountToCents(v);
        if (c == null || c <= 0) {
          return context.tr('Некорректная сумма', 'Invalid amount');
        }
        return null;
      },
      builder: (fieldState) {
        final hasError = fieldState.hasError;
        final borderColor = hasError
            ? colors.expense
            : (_focused ? widget.accentColor : colors.border);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              onFocusChange: (f) => setState(() => _focused = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _focused
                      ? colors.surface
                      : colors.surfaceSecondary.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: _focused || hasError ? 1.5 : 1.0,
                  ),
                  boxShadow: _focused
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    // Sign or icon badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(
                          alpha: _focused ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: isSignPrefix
                          ? Text(
                              widget.prefix,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: widget.accentColor,
                              ),
                            )
                          : Icon(
                              Icons.payments_outlined,
                              size: 17,
                              color: widget.accentColor,
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Large tabular number input
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: const [
                          ThousandsSeparatorInputFormatter(),
                        ],
                        autofocus: widget.autofocus,
                        textInputAction: widget.textInputAction,
                        onSubmitted: widget.onFieldSubmitted ??
                            (_) {
                              if (widget.textInputAction == TextInputAction.next) {
                                FocusScope.of(context).nextFocus();
                              } else {
                                FocusScope.of(context).unfocus();
                              }
                            },
                        onChanged: (v) => fieldState.didChange(v),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: colors.textMuted.withValues(alpha: 0.55),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                          filled: false,
                        ),
                      ),
                    ),

                    if (_hasText) ...[
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.controller.clear();
                          fieldState.didChange('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.cancel_rounded,
                            size: 18,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],

                    // Currency Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        resolvedCurrency,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasError && fieldState.errorText != null)
              FormFieldError(text: fieldState.errorText!),
          ],
        );
      },
    );
  }
}

// ─── Text field ───────────────────────────────────────────────────────────────

class FormTextField extends StatefulWidget {
  const FormTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.obscureText = false,
    this.prefixIcon,
    this.trailing,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final int? minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? trailing;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<FormTextField> createState() => _FormTextFieldState();
}

class _FormTextFieldState extends State<FormTextField> {
  bool _focused = false;
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isMultiline = !widget.obscureText &&
        (widget.maxLines > 1 ||
            (widget.minLines != null && widget.minLines! > 1));

    return FormField<String>(
      initialValue: widget.controller.text,
      validator: (_) =>
          widget.validator != null ? widget.validator!(widget.controller.text) : null,
      builder: (fieldState) {
        final hasError = fieldState.hasError;
        final borderColor = hasError
            ? colors.expense
            : (_focused ? colors.primary : colors.border);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              onFocusChange: (f) => setState(() => _focused = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: _focused
                      ? colors.surface
                      : colors.surfaceSecondary.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: _focused || hasError ? 1.5 : 1.0,
                  ),
                  boxShadow: _focused
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: isMultiline
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    if (widget.prefixIcon != null)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 14,
                          top: isMultiline ? 14 : 0,
                        ),
                        child: Icon(
                          widget.prefixIcon,
                          size: 18,
                          color: _focused ? colors.primary : colors.textMuted,
                        ),
                      ),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        minLines: widget.obscureText ? 1 : widget.minLines,
                        maxLines: widget.obscureText ? 1 : widget.maxLines,
                        obscureText: _obscured,
                        keyboardType: widget.keyboardType,
                        inputFormatters: widget.inputFormatters,
                        textCapitalization: widget.textCapitalization,
                        autofocus: widget.autofocus,
                        textInputAction: widget.textInputAction ??
                            (isMultiline
                                ? TextInputAction.newline
                                : TextInputAction.done),
                        onSubmitted: isMultiline
                            ? widget.onFieldSubmitted
                            : (v) {
                                if (widget.onFieldSubmitted != null) {
                                  widget.onFieldSubmitted!(v);
                                  return;
                                }
                                final action =
                                    widget.textInputAction ?? TextInputAction.done;
                                if (action == TextInputAction.next) {
                                  FocusScope.of(context).nextFocus();
                                } else {
                                  FocusScope.of(context).unfocus();
                                }
                              },
                        onChanged: (v) => fieldState.didChange(v),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: colors.textMuted,
                          ),
                          contentPadding: EdgeInsets.fromLTRB(
                            widget.prefixIcon != null ? 10 : 16,
                            14,
                            widget.trailing != null ? 4 : 16,
                            14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          suffixIcon: widget.obscureText
                              ? IconButton(
                                  onPressed: () =>
                                      setState(() => _obscured = !_obscured),
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
                    if (widget.trailing != null)
                      Padding(
                        padding: EdgeInsets.only(
                          right: 8,
                          top: isMultiline ? 8 : 0,
                        ),
                        child: widget.trailing!,
                      ),
                  ],
                ),
              ),
            ),
            if (hasError && fieldState.errorText != null)
              FormFieldError(text: fieldState.errorText!),
          ],
        );
      },
    );
  }
}

class FormFieldError extends StatelessWidget {
  const FormFieldError({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 13, color: colors.expense),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.expense,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date picker with quick chips ─────────────────────────────────────────────

class FormDatePicker extends StatelessWidget {
  const FormDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accentColor,
    this.allowPast = false,
    this.nullable = false,
    this.hint,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final Color accentColor;
  final bool allowPast;
  final bool nullable;
  final String? hint;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasValue = value != null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final inWeek = today.add(const Duration(days: 7));

    String? relativeBadge;
    if (hasValue) {
      if (_isSameDay(value!, today)) {
        relativeBadge = context.tr('Сегодня', 'Today');
      } else if (_isSameDay(value!, yesterday)) {
        relativeBadge = context.tr('Вчера', 'Yesterday');
      } else if (_isSameDay(value!, tomorrow)) {
        relativeBadge = context.tr('Завтра', 'Tomorrow');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            HapticFeedback.selectionClick();
            final initial =
                value ?? (allowPast ? now : now.add(const Duration(days: 7)));
            final first = allowPast
                ? DateTime(2020)
                : DateTime(now.year, now.month, now.day);
            final last = allowPast
                ? now.add(const Duration(days: 365))
                : now.add(const Duration(days: 365 * 3));

            final safeInitial = initial.isBefore(first)
                ? first
                : (initial.isAfter(last) ? last : initial);

            final picked = await showDatePicker(
              context: context,
              initialDate: safeInitial,
              firstDate: first,
              lastDate: last,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: Theme.of(ctx)
                      .colorScheme
                      .copyWith(primary: accentColor),
                ),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: hasValue
                  ? colors.surface
                  : colors.surfaceSecondary.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue
                    ? accentColor.withValues(alpha: 0.65)
                    : colors.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hasValue
                        ? accentColor.withValues(alpha: 0.12)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: hasValue ? accentColor : colors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue
                        ? DateHelper.formatDate(value!)
                        : hint ??
                            (nullable
                                ? context.tr(
                                    'Без срока (нажмите для выбора)',
                                    'No deadline (tap to select)',
                                  )
                                : context.tr('Выберите дату', 'Select date')),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          hasValue ? FontWeight.w700 : FontWeight.w400,
                      color:
                          hasValue ? colors.textPrimary : colors.textMuted,
                    ),
                  ),
                ),
                if (relativeBadge != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      relativeBadge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (hasValue && nullable)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(null);
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.textMuted,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Quick date pills
        Row(
          children: allowPast
              ? [
                  _QuickDateChip(
                    label: context.tr('Сегодня', 'Today'),
                    selected: hasValue && _isSameDay(value!, today),
                    accentColor: accentColor,
                    onTap: () => onChanged(today),
                  ),
                  const SizedBox(width: 6),
                  _QuickDateChip(
                    label: context.tr('Вчера', 'Yesterday'),
                    selected: hasValue && _isSameDay(value!, yesterday),
                    accentColor: accentColor,
                    onTap: () => onChanged(yesterday),
                  ),
                ]
              : [
                  _QuickDateChip(
                    label: context.tr('Завтра', 'Tomorrow'),
                    selected: hasValue && _isSameDay(value!, tomorrow),
                    accentColor: accentColor,
                    onTap: () => onChanged(tomorrow),
                  ),
                  const SizedBox(width: 6),
                  _QuickDateChip(
                    label: context.tr('Через 7 дней', 'In 7 days'),
                    selected: hasValue && _isSameDay(value!, inWeek),
                    accentColor: accentColor,
                    onTap: () => onChanged(inWeek),
                  ),
                  if (nullable && hasValue) ...[
                    const SizedBox(width: 6),
                    _QuickDateChip(
                      label: context.tr('Сбросить', 'Clear'),
                      selected: false,
                      accentColor: colors.textMuted,
                      onTap: () => onChanged(null),
                    ),
                  ],
                ],
        ),
      ],
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.14)
              : colors.surfaceSecondary.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accentColor : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Submit button ────────────────────────────────────────────────────────────

class FormSubmitButton extends StatefulWidget {
  const FormSubmitButton({
    super.key,
    required this.label,
    required this.accentColor,
    required this.isLoading,
    required this.onPressed,
    required this.icon,
  });

  final String label;
  final Color accentColor;
  final bool isLoading;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  State<FormSubmitButton> createState() => _FormSubmitButtonState();
}

class _FormSubmitButtonState extends State<FormSubmitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.isLoading ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.isLoading ? null : () => setState(() => _pressed = false),
      onTap: widget.isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onPressed();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 54,
          decoration: BoxDecoration(
            color: widget.isLoading
                ? widget.accentColor.withValues(alpha: 0.6)
                : widget.accentColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isLoading
                ? []
                : [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 19, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Stagger animation helper ─────────────────────────────────────────────────

/// Hardware-accelerated staggered entrance animation for form fields.
class FormStaggerItem extends StatelessWidget {
  const FormStaggerItem({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  final AnimationController animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.06).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);

    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
