import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/appointement_service.dart';

class AppointmentsCalendarPage extends StatefulWidget {
  const AppointmentsCalendarPage({super.key});

  @override
  State<AppointmentsCalendarPage> createState() => _AppointmentsCalendarPageState();
}

class _AppointmentsCalendarPageState extends State<AppointmentsCalendarPage> {
  final _service = AppointmentService();
  Map<DateTime, List<Appointment>> _events = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final all = await _service.getAppointmentsForUser(user.uid);
      final map = <DateTime, List<Appointment>>{};
      for (final a in all) {
        final day = DateTime(a.start.year, a.start.month, a.start.day);
        map.putIfAbsent(day, () => []).add(a);
      }
      setState(() => _events = map);
    } catch (e) {
      // ignore errors for now
    }
  }

  // helper: get events for a particular day (normalizes date)
  List<Appointment> _eventsForDay(DateTime day) =>
      _events[DateTime(day.year, day.month, day.day)] ?? [];

  @override
  Widget build(BuildContext context) {
    // Simple calendar-less view: list days with appointments and items per day.
    final days = _events.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario de Citas')),
      body: days.isEmpty
          ? const Center(child: Text('No hay citas para mostrar en el calendario'))
          : ListView.builder(
              itemCount: days.length,
              itemBuilder: (context, idx) {
                final day = days[idx];
                final items = _eventsForDay(day);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ...items.map((a) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(a.motivo),
                              subtitle: Text('${a.start} - ${a.end}'),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
