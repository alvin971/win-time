import 'package:intl/intl.dart';

/// Utilitaire pour formater les dates
class DateFormatter {
  DateFormatter._();

  /// Format de date complet : "25 décembre 2024"
  static String formatFullDate(DateTime date, {String locale = 'fr_FR'}) {
    return DateFormat.yMMMMd(locale).format(date);
  }

  /// Format de date court : "25/12/2024"
  static String formatShortDate(DateTime date, {String locale = 'fr_FR'}) {
    return DateFormat.yMd(locale).format(date);
  }

  /// Format d'heure : "14:30"
  static String formatTime(DateTime date) {
    return DateFormat.Hm().format(date);
  }

  /// Format date et heure : "25/12/2024 14:30"
  static String formatDateTime(DateTime date, {String locale = 'fr_FR'}) {
    return DateFormat.yMd(locale).add_Hm().format(date);
  }

  /// Format relatif : "Il y a 5 minutes", "Dans 2 heures"
  static String formatRelative(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final difference = reference.difference(date);

    if (difference.isNegative) {
      // Date future
      final futureDiff = date.difference(reference);
      if (futureDiff.inMinutes < 1) {
        return 'Dans quelques secondes';
      } else if (futureDiff.inMinutes < 60) {
        return 'Dans ${futureDiff.inMinutes} minute${futureDiff.inMinutes > 1 ? 's' : ''}';
      } else if (futureDiff.inHours < 24) {
        return 'Dans ${futureDiff.inHours} heure${futureDiff.inHours > 1 ? 's' : ''}';
      } else if (futureDiff.inDays < 7) {
        return 'Dans ${futureDiff.inDays} jour${futureDiff.inDays > 1 ? 's' : ''}';
      } else {
        return formatShortDate(date);
      }
    } else {
      // Date passée
      if (difference.inSeconds < 60) {
        return 'À l\'instant';
      } else if (difference.inMinutes < 60) {
        return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
      } else {
        return formatShortDate(date);
      }
    }
  }

  /// Formate une durée en minutes en format lisible
  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours h';
      } else {
        return '$hours h $remainingMinutes min';
      }
    }
  }

  /// Vérifie si une date est aujourd'hui
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Vérifie si une date est demain
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  /// Vérifie si une date est hier
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}
