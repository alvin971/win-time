import 'package:equatable/equatable.dart';

import '../enums/day_of_week.dart';

class TimeSlot extends Equatable {
  /// Format "HH:mm" (24h, ex: "09:00", "23:30").
  final String openTime;
  final String closeTime;

  const TimeSlot({required this.openTime, required this.closeTime});

  /// Compare 2 strings "HH:mm" pour savoir si un timestamp tombe dedans.
  bool containsClock(String clock) {
    return clock.compareTo(openTime) >= 0 && clock.compareTo(closeTime) < 0;
  }

  @override
  List<Object?> get props => [openTime, closeTime];
}

class DaySchedule extends Equatable {
  final bool isOpen;
  final TimeSlot? morning;
  final TimeSlot? afternoon;

  const DaySchedule({
    required this.isOpen,
    this.morning,
    this.afternoon,
  });

  factory DaySchedule.closed() => const DaySchedule(isOpen: false);

  bool isOpenAt(String clock) {
    if (!isOpen) return false;
    if (morning?.containsClock(clock) ?? false) return true;
    if (afternoon?.containsClock(clock) ?? false) return true;
    return false;
  }

  @override
  List<Object?> get props => [isOpen, morning, afternoon];
}

class BusinessHours extends Equatable {
  final Map<DayOfWeek, DaySchedule> schedule;

  const BusinessHours({required this.schedule});

  factory BusinessHours.allClosed() => BusinessHours(
        schedule: {
          for (final d in DayOfWeek.values) d: DaySchedule.closed(),
        },
      );

  /// Retourne true si le restaurant est ouvert maintenant (timezone locale).
  bool isOpenNow([DateTime? now]) {
    final n = now ?? DateTime.now();
    final day = DayOfWeekX.fromIso(n.weekday);
    final clock =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
    final s = schedule[day];
    if (s == null) return false;
    return s.isOpenAt(clock);
  }

  DaySchedule? scheduleFor(DayOfWeek day) => schedule[day];

  @override
  List<Object?> get props => [schedule];
}
