import 'package:flutter/material.dart';

/// Shows initials-based avatar for customers.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.fontSize,
  });

  final String name;
  final double size;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final color = _colorForName(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontSize: fontSize ?? size * 0.38,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _colorForName(String name) {
    const colors = [
      Color(0xFF0F766E),
      Color(0xFF14B8A6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF0D9488),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return colors[idx];
  }
}
