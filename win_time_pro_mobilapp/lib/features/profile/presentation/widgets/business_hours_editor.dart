import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';

/// Éditeur d'horaires hebdomadaires.
///
/// 7 lignes (Lundi → Dimanche). Pour chaque jour :
///   - Switch "ouvert/fermé"
///   - Si ouvert : 1 ou 2 plages horaires (matin / après-midi via toggle
///     "Service continu")
///   - TimePicker pour open/close de chaque plage
///
/// Bouton "Copier sur tous les jours" pour appliquer le planning du lundi
/// à toute la semaine.
///
/// Sérialise vers [BusinessHours] de shared_core.
class BusinessHoursEditor extends StatefulWidget {
  final BusinessHours initial;
  final ValueChanged<BusinessHours> onChanged;

  const BusinessHoursEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<BusinessHoursEditor> createState() => _BusinessHoursEditorState();
}

class _BusinessHoursEditorState extends State<BusinessHoursEditor> {
  late Map<DayOfWeek, _DayEditState> _state;

  @override
  void initState() {
    super.initState();
    _state = {
      for (final d in DayOfWeek.values)
        d: _DayEditState.fromSchedule(widget.initial.schedule[d]),
    };
  }

  void _emit() {
    final schedule = <DayOfWeek, DaySchedule>{};
    for (final d in DayOfWeek.values) {
      schedule[d] = _state[d]!.toSchedule();
    }
    widget.onChanged(BusinessHours(schedule: schedule));
  }

  void _copyMondayToAll() {
    final monday = _state[DayOfWeek.monday]!;
    setState(() {
      for (final d in DayOfWeek.values) {
        _state[d] = monday.clone();
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _copyMondayToAll,
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copier lundi sur tous les jours'),
            ),
          ],
        ),
        for (final day in DayOfWeek.values)
          _DayRow(
            day: day,
            state: _state[day]!,
            onChanged: (s) {
              setState(() => _state[day] = s);
              _emit();
            },
          ),
      ],
    );
  }
}

// ─── Internal state model ────────────────────────────────────────────────

class _DayEditState {
  bool isOpen;
  bool continuousService;
  TimeOfDay morningOpen;
  TimeOfDay morningClose;
  TimeOfDay afternoonOpen;
  TimeOfDay afternoonClose;

  _DayEditState({
    required this.isOpen,
    required this.continuousService,
    required this.morningOpen,
    required this.morningClose,
    required this.afternoonOpen,
    required this.afternoonClose,
  });

  factory _DayEditState.fromSchedule(DaySchedule? sched) {
    if (sched == null || !sched.isOpen) {
      return _DayEditState(
        isOpen: false,
        continuousService: true,
        morningOpen: const TimeOfDay(hour: 11, minute: 0),
        morningClose: const TimeOfDay(hour: 23, minute: 0),
        afternoonOpen: const TimeOfDay(hour: 19, minute: 0),
        afternoonClose: const TimeOfDay(hour: 22, minute: 0),
      );
    }
    final morning = sched.morning;
    final afternoon = sched.afternoon;
    return _DayEditState(
      isOpen: true,
      continuousService: afternoon == null,
      morningOpen: _parseClock(morning?.openTime ?? '11:00'),
      morningClose: _parseClock(morning?.closeTime ?? '14:30'),
      afternoonOpen: _parseClock(afternoon?.openTime ?? '19:00'),
      afternoonClose: _parseClock(afternoon?.closeTime ?? '22:30'),
    );
  }

  _DayEditState clone() => _DayEditState(
        isOpen: isOpen,
        continuousService: continuousService,
        morningOpen: morningOpen,
        morningClose: morningClose,
        afternoonOpen: afternoonOpen,
        afternoonClose: afternoonClose,
      );

  DaySchedule toSchedule() {
    if (!isOpen) return DaySchedule.closed();
    final morning = TimeSlot(
      openTime: _formatClock(morningOpen),
      closeTime: _formatClock(morningClose),
    );
    final afternoon = continuousService
        ? null
        : TimeSlot(
            openTime: _formatClock(afternoonOpen),
            closeTime: _formatClock(afternoonClose),
          );
    return DaySchedule(
      isOpen: true,
      morning: morning,
      afternoon: afternoon,
    );
  }
}

TimeOfDay _parseClock(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 0,
    minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
  );
}

String _formatClock(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// ─── Day row widget ──────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final DayOfWeek day;
  final _DayEditState state;
  final ValueChanged<_DayEditState> onChanged;

  const _DayRow({
    required this.day,
    required this.state,
    required this.onChanged,
  });

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) =>
          MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    day.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  state.isOpen ? 'Ouvert' : 'Fermé',
                  style: TextStyle(
                    color: state.isOpen ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: state.isOpen,
                  onChanged: (v) {
                    state.isOpen = v;
                    onChanged(state);
                  },
                ),
              ],
            ),
            if (state.isOpen) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Service continu', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  Switch(
                    value: state.continuousService,
                    onChanged: (v) {
                      state.continuousService = v;
                      onChanged(state);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _TimeRange(
                label: state.continuousService ? 'Ouverture' : 'Matin',
                from: state.morningOpen,
                to: state.morningClose,
                onFromTap: () => _pickTime(context, state.morningOpen, (t) {
                  state.morningOpen = t;
                  onChanged(state);
                }),
                onToTap: () => _pickTime(context, state.morningClose, (t) {
                  state.morningClose = t;
                  onChanged(state);
                }),
              ),
              if (!state.continuousService) ...[
                const SizedBox(height: 4),
                _TimeRange(
                  label: 'Après-midi',
                  from: state.afternoonOpen,
                  to: state.afternoonClose,
                  onFromTap: () => _pickTime(context, state.afternoonOpen, (t) {
                    state.afternoonOpen = t;
                    onChanged(state);
                  }),
                  onToTap: () => _pickTime(context, state.afternoonClose, (t) {
                    state.afternoonClose = t;
                    onChanged(state);
                  }),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeRange extends StatelessWidget {
  final String label;
  final TimeOfDay from;
  final TimeOfDay to;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;

  const _TimeRange({
    required this.label,
    required this.from,
    required this.to,
    required this.onFromTap,
    required this.onToTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: onFromTap,
            child: Text(_formatClock(from)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('–'),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: onToTap,
            child: Text(_formatClock(to)),
          ),
        ),
      ],
    );
  }
}
