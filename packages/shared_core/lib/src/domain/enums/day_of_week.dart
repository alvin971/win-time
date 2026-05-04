enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

extension DayOfWeekX on DayOfWeek {
  /// 1 (lundi) à 7 (dimanche), aligné sur DateTime.weekday.
  int get isoWeekday {
    switch (this) {
      case DayOfWeek.monday:
        return 1;
      case DayOfWeek.tuesday:
        return 2;
      case DayOfWeek.wednesday:
        return 3;
      case DayOfWeek.thursday:
        return 4;
      case DayOfWeek.friday:
        return 5;
      case DayOfWeek.saturday:
        return 6;
      case DayOfWeek.sunday:
        return 7;
    }
  }

  String get displayName {
    switch (this) {
      case DayOfWeek.monday:
        return 'Lundi';
      case DayOfWeek.tuesday:
        return 'Mardi';
      case DayOfWeek.wednesday:
        return 'Mercredi';
      case DayOfWeek.thursday:
        return 'Jeudi';
      case DayOfWeek.friday:
        return 'Vendredi';
      case DayOfWeek.saturday:
        return 'Samedi';
      case DayOfWeek.sunday:
        return 'Dimanche';
    }
  }

  static DayOfWeek fromIso(int isoWeekday) {
    return DayOfWeek.values[(isoWeekday - 1).clamp(0, 6)];
  }

  static DayOfWeek fromString(String? raw) {
    if (raw == null) return DayOfWeek.monday;
    return DayOfWeek.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => DayOfWeek.monday,
    );
  }
}
