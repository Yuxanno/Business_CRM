import 'package:intl/intl.dart';

class DateHelper {
  DateHelper._();

  static String formatDate(DateTime date, {String format = 'dd.MM.yyyy'}) {
    return DateFormat(format).format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  static String formatMonthYear(DateTime date, {String locale = 'ru'}) {
    return DateFormat('MMMM yyyy', locale).format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('dd MMM', 'ru').format(date);
  }

  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Сегодня';
    if (diff.inDays == 1) return 'Вчера';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return formatDate(date);
  }

  static List<DateTime> monthsInYear(int year) {
    return List.generate(12, (i) => DateTime(year, i + 1));
  }

  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }
}
