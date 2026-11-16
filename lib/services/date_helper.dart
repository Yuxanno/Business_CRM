import 'package:intl/intl.dart';
import '../l10n/app_tr.dart';

class DateHelper {
  DateHelper._();

  static String formatDate(DateTime date, {String format = 'dd.MM.yyyy'}) {
    return DateFormat(format).format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  static const List<String> _ruMonthsNominative = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  static const List<String> _enMonthsNominative = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String formatMonthYear(DateTime date, {String? locale}) {
    final resolved = locale ?? (AppTr.isEn ? 'en' : 'ru');
    if (resolved == 'en') {
      final monthName = _enMonthsNominative[(date.month - 1).clamp(0, 11)];
      return '$monthName ${date.year}';
    }
    if (resolved == 'ru') {
      final monthName = _ruMonthsNominative[(date.month - 1).clamp(0, 11)];
      return '$monthName ${date.year}';
    }
    return DateFormat('MMMM yyyy', resolved).format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('dd MMM', AppTr.isEn ? 'en' : 'ru').format(date);
  }

  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return AppTr.tr('Сегодня', 'Today');
    if (diff.inDays == 1) return AppTr.tr('Вчера', 'Yesterday');
    if (diff.inDays < 7) {
      return AppTr.tr('${diff.inDays} дн. назад', '${diff.inDays}d ago');
    }
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
    if (hour < 12) return AppTr.tr('Доброе утро', 'Good morning');
    if (hour < 18) return AppTr.tr('Добрый день', 'Good afternoon');
    return AppTr.tr('Добрый вечер', 'Good evening');
  }
}
