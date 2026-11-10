/// Safe financial calculations using integer cents.
/// NEVER use double arithmetic for money.
class FinancialCalculator {
  FinancialCalculator._();

  /// Convert user-entered amount string to integer cents.
  /// Returns null if the input is invalid.
  static int? parseAmountToCents(String input) {
    if (input.trim().isEmpty) return null;
    // Allow comma as decimal separator and remove spaces.
    final normalized = input.trim().replaceAll(',', '.').replaceAll(' ', '');
    final value = double.tryParse(normalized);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  /// Format integer with space as thousand separator.
  /// Example: 1000000 → "1 000 000"
  static String _formatWithSpaces(int value) {
    final str = value.abs().toString();
    final buffer = StringBuffer();
    int counter = 0;
    
    for (int i = str.length - 1; i >= 0; i--) {
      if (counter > 0 && counter % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
      counter++;
    }
    
    final result = buffer.toString().split('').reversed.join('');
    return value < 0 ? '-$result' : result;
  }

  /// Format integer cents to display string.
  /// RUB: без копеек если их нет (1 000 ₽)
  /// USD/EUR/другие: всегда с центами (1 000.00 $)
  static String formatCents(int cents, {String currency = 'RUB'}) {
    final main = cents ~/ 100;
    final fraction = (cents % 100).abs();
    
    final mainFormatted = _formatWithSpaces(main);
    
    // Для рублей и тенге показываем копейки только если они есть
    final hideZeroFraction = currency == 'RUB' || 
                             currency == 'KZT' || 
                             currency == 'UZS';
    
    if (hideZeroFraction && fraction == 0) {
      return '$mainFormatted $currency';
    }
    
    return '$mainFormatted.${fraction.toString().padLeft(2, '0')} $currency';
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
