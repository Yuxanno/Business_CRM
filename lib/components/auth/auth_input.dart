import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Underline-only auth field — leaner than the usual rounded box inputs.
class AuthInput extends StatefulWidget {
  const AuthInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.icon,
    this.onFieldSubmitted,
    this.errorText,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final Icon? icon;
  final Function(String)? onFieldSubmitted;
  final String? errorText;
  final TextInputAction? textInputAction;

  @override
  State<AuthInput> createState() => _AuthInputState();
}

class _AuthInputState extends State<AuthInput> {
  late bool _obscured;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _focusNode = FocusNode()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final focused = _focusNode.hasFocus;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    final lineColor = hasError
        ? colors.danger
        : focused
            ? colors.primary
            : colors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: hasError
                ? colors.danger
                : focused
                    ? colors.primary
                    : colors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: _obscured,
          onSubmitted: widget.onFieldSubmitted,
          textInputAction: widget.textInputAction,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            letterSpacing: -0.2,
          ),
          cursorColor: colors.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: colors.textMuted,
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
            prefixIcon: widget.icon == null
                ? null
                : IconTheme(
                    data: IconThemeData(
                      color: focused ? colors.primary : colors.textMuted,
                      size: 22,
                    ),
                    child: widget.icon!,
                  ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: colors.textMuted,
                      size: 20,
                    ),
                  )
                : null,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: AppSpacing.md,
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: lineColor, width: focused ? 2 : 1.5),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: lineColor, width: 1.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: lineColor, width: 2),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.danger, width: 1.5),
            ),
            focusedErrorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.danger, width: 2),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: TextStyle(
              fontSize: 12,
              color: colors.danger,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
