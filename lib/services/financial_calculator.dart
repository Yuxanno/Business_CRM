/// Safe financial calculations using integer cents.
/// NEVER use double arithmetic for money.
class FinancialCalculator {
  FinancialCalculator._();

  /// Convert user-entered amount string to integer cents.
  /// Returns null if the input is invalid.
  static int? parseAmountToCents(String input) {
    if (input.trim().isEmpty) return null;
    // Allow comma as decimal separator.
    final normalized = input.trim().replaceAll(',', '.').replaceAll(' ', '');
    final value = double.tryParse(normalized);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  /// Format integer cents to display string.
  static String formatCents(int cents, {String currency = 'RUB'}) {
    final rubles = cents ~/ 100;
    final kopecks = (cents % 100).abs();
    if (kopecks == 0) {
      return '$rubles $currency';
    }
    return '$rubles.${kopecks.toString().padLeft(2, '0')} $currency';
  }

  /// Format cents to compact display (e.g. 1 500 000 → 1.5M).
  static String formatCentsCompact(int cents, {String currency = 'RUB'}) {
    final value = cents / 100;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M $currency';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K $currency';
    }
    return formatCents(cents, currency: currency);
  }

  /// Compute net cash result (income - expenses) in cents.
  static int netResult(int incomeCents, int expenseCents) {
    return incomeCents - expenseCents;
  }

  /// Safe percentage (0–100). Returns 0 if total is 0.
  static double percentage(int part, int total) {
    if (total <= 0) return 0.0;
    return (part / total * 100).clamp(0.0, 100.0);
  }

  /// Clamp payment to not exceed remaining balance.
  static int clampPayment(int paymentCents, int remainingCents) {
    return paymentCents.clamp(0, remainingCents);
  }
}
