/// Shared form widgets used across all modal form sheets.
/// Exported from here so customer/order/debt forms can import them.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/financial_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// ─── Amount input ─────────────────────────────────────────────────────────────

/// Large animated amount field with coloured prefix character.
class FormAmountField extends StatefulWidget {
  const FormAmountField({
    super.key,
    required this.controller,
    required this.accentColor,
    required this.prefix,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final Color accentColor;
  final String prefix;
  final bool autofocus;

  @override
  State<FormAmountField> createState() => _FormAmountFieldState();
}

class _FormAmountFieldState extends State<FormAmountField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: _focused
              ? widget.accentColor.withValues(alpha: 0.05)
              : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? widget.accentColor : colors.border,
            width: _focused ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.lg),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _focused ? widget.accentColor : colors.textMuted,
              ),
              child: Text(widget.prefix),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                autofocus: widget.autofocus,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: colors.textMuted,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  filled: false,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите сумму';
                  final c = FinancialCalculator.parseAmountToCents(v);
                  if (c == null || c <= 0) return 'Некорректная сумма';
                  return null;
                },
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ─── Text field ───────────────────────────────────────────────────────────────

class FormTextField extends StatefulWidget {
  const FormTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool obscureText;

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

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _focused
              ? colors.primary.withValues(alpha: 0.03)
              : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? colors.primary : colors.border,
            width: 1,
          ),
        ),
        child: TextFormField(
          controller: widget.controller,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          textCapitalization: widget.textCapitalization,
          autofocus: widget.autofocus,
          style: TextStyle(fontSize: 15, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(fontSize: 15, color: colors.textMuted),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
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
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: colors.expense),
      ),
    );
  }
}

// ─── Date picker ──────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasValue = value != null;

    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final initial =
            value ?? (allowPast ? now : now.add(const Duration(days: 7)));
        final first = allowPast ? DateTime(2020) : now;
        final last =
            allowPast ? now : now.add(const Duration(days: 365 * 3));

        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
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
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: hasValue
              ? accentColor.withValues(alpha: 0.05)
              : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue ? accentColor : colors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: hasValue ? accentColor : colors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                hasValue
                    ? '${value!.day.toString().padLeft(2, '0')}'
                        '.${value!.month.toString().padLeft(2, '0')}'
                        '.${value!.year}'
                    : hint ?? (nullable
                        ? 'Выберите дату (необязательно)'
                        : 'Выберите дату'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      hasValue ? FontWeight.w500 : FontWeight.w400,
                  color:
                      hasValue ? colors.textPrimary : colors.textMuted,
                ),
              ),
            ),
            if (hasValue && nullable)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 14, color: colors.textMuted),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Submit button ────────────────────────────────────────────────────────────

class FormSubmitButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: isLoading
              ? accentColor.withValues(alpha: 0.6)
              : accentColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Stagger animation helper ─────────────────────────────────────────────────

/// Animates each form field in with a slight delay (stagger effect).
/// [index] controls the delay offset; [animation] is a shared controller.
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
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);

    final fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
    final slide = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (ctx, childWidget) => Opacity(
        opacity: fade.value,
        child: Transform.translate(
          offset: Offset(0, slide.value),
          child: childWidget,
        ),
      ),
    );
  }
}
