import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter/material.dart';

class GraphicsPage extends StatefulWidget {
  const GraphicsPage({super.key});

  @override
  State<GraphicsPage> createState() => _GraphicsPageState();
}

class _GraphicsPageState extends State<GraphicsPage> {
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gráficas')),
        body: const Center(child: Text('Necesitas iniciar sesión')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas / Gráficas')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
        builder: (context, userSnap) {
          if (userSnap.hasError) return Center(child: Text('Error: ${userSnap.error}'));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          final data = userSnap.data!.data();
          final role = (data?['role'] ?? '').toString().toLowerCase();
          final isDoctor = role == 'medico' || role == 'médico' || role == 'doctor';
          if (!isDoctor) return const Center(child: Text('Esta sección está disponible solo para médicos.'));

          // Streams
          final citasStream = FirebaseFirestore.instance.collection('citas').where('id_medico', isEqualTo: user.uid).snapshots();
          final cancelStream = FirebaseFirestore.instance.collection('citas_canceladas').where('appointment_snapshot.id_medico', isEqualTo: user.uid).snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: citasStream,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: cancelStream,
                builder: (context, cancelSnap) {
                  // If reading cancellation logs is denied by rules, don't block the chart.
                  List<QueryDocumentSnapshot<Map<String, dynamic>>> cancelDocsList = [];
                  if (cancelSnap.hasError) {
                    final err = cancelSnap.error;
                    if (err is FirebaseException && err.code == 'permission-denied') {
                      // proceed without logs
                      cancelDocsList = [];
                    } else {
                      return Center(child: Text('Error: ${cancelSnap.error}'));
                    }
                  } else if (!cancelSnap.hasData) {
                    // still loading logs: treat as empty for now
                    cancelDocsList = [];
                  } else {
                    cancelDocsList = cancelSnap.data!.docs;
                  }

                  final docs = snap.data!.docs;
                  final cancelDocs = cancelDocsList;

                  // 1) Citas por mes (últimos 6 meses)
                  final now = DateTime.now();
                  final months = List.generate(6, (i) {
                    final m = DateTime(now.year, now.month - (5 - i));
                    return DateTime(m.year, m.month);
                  });
                  final monthCounts = Map<String, int>.fromEntries(months.map((m) => MapEntry('${m.year}-${m.month}', 0)));

                  // Build a set of cancelled appointment IDs from both sources
                  final Set<String> cancelledIds = {};

                  // First, mark appointments whose status is 'cancelada'
                  for (final d in docs) {
                    final mp = d.data();
                    if (mp['start'] != null) {
                      try {
                        final ts = mp['start'] as Timestamp;
                        final dt = ts.toDate();
                        final key = '${dt.year}-${dt.month}';
                        if (monthCounts.containsKey(key)) monthCounts[key] = monthCounts[key]! + 1;
                      } catch (_) {}
                    }
                    final status = (mp['status'] ?? '').toString().toLowerCase();
                    if (status.contains('cancel')) cancelledIds.add(d.id);
                  }

                  // Then, include appointment_ids reported in citas_canceladas
                  for (final cd in cancelDocs) {
                    final cdata = cd.data();
                    final apptId = cdata['appointment_id']?.toString();
                    if (apptId != null && apptId.isNotEmpty) cancelledIds.add(apptId);
                  }

                  // Now compute completed / canceled / other counts without double-counting
                  int completed = 0, other = 0;
                  for (final d in docs) {
                    final mp = d.data();
                    final id = d.id;
                    final status = (mp['status'] ?? '').toString().toLowerCase();
                    if (cancelledIds.contains(id)) {
                      // counted as cancelled via set
                      continue;
                    }
                    if (status.contains('complet')) {
                      completed++;
                    } else {
                      other++;
                    }
                  }

                  final canceled = cancelledIds.length;

                  final monthLabels = months.map((m) => '${m.month}/${m.year.toString().substring(2)}').toList();
                  final monthValues = months.map((m) => monthCounts['${m.year}-${m.month}'] ?? 0).toList();

                  final int maxMonthValue = monthValues.isEmpty ? 0 : monthValues.reduce((a, b) => a > b ? a : b);
                  final double yMax = (maxMonthValue <= 0) ? 1.0 : (maxMonthValue.toDouble() + 1.0);
                  double yInterval = 1.0;
                  if (maxMonthValue > 0) {
                    final calc = (maxMonthValue / 3.0);
                    yInterval = calc.ceilToDouble();
                    if (yInterval <= 0) yInterval = 1.0;
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Citas por mes (últimos 6 meses)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 260,
                                  child: SfCartesianChart(
                                    primaryXAxis: CategoryAxis(labelRotation: 0),
                                    primaryYAxis: NumericAxis(minimum: 0, maximum: yMax, interval: yInterval),
                                    tooltipBehavior: TooltipBehavior(enable: true),
                                    series: <ColumnSeries<_MonthData, String>>[
                                      ColumnSeries<_MonthData, String>(
                                        dataSource: List.generate(monthLabels.length, (i) => _MonthData(monthLabels[i], monthValues[i])),
                                        xValueMapper: (_MonthData md, _) => md.label,
                                        yValueMapper: (_MonthData md, _) => md.value,
                                        color: Theme.of(context).primaryColor,
                                        dataLabelSettings: const DataLabelSettings(isVisible: true),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(spacing: 8, children: List.generate(monthLabels.length, (i) => Chip(label: Text('${monthLabels[i]}: ${monthValues[i]}')))),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Citas: completadas vs canceladas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 260,
                                  child: SfCircularChart(
                                    tooltipBehavior: TooltipBehavior(enable: true),
                                    series: <CircularSeries<_StatusData, String>>[
                                      PieSeries<_StatusData, String>(
                                        dataSource: [
                                          _StatusData('Completadas', completed.toDouble(), Colors.green),
                                          _StatusData('Canceladas', canceled.toDouble(), Colors.red),
                                          _StatusData('Otras', other.toDouble(), Colors.blue),
                                        ],
                                        xValueMapper: (_StatusData data, _) => data.label,
                                        yValueMapper: (_StatusData data, _) => data.value,
                                        pointColorMapper: (_StatusData data, _) => data.color,
                                        dataLabelSettings: const DataLabelSettings(isVisible: true),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                                  _legend(Colors.green, 'Completadas', completed),
                                  _legend(Colors.red, 'Canceladas', canceled),
                                  _legend(Colors.blue, 'Otras', other),
                                ]),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Text('Notas:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('- Estas gráficas usan las citas donde el campo `id_medico` coincide con tu UID.'),
                        const Text('- Asegúrate de que los documentos en `citas` contienen `start` (Timestamp) y `status` (String).'),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _legend(Color color, String label, int value) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text('$label: $value'),
      ],
    );
  }
}

// Small helper data classes for the charts
class _MonthData {
  final String label;
  final int value;
  _MonthData(this.label, this.value);
}

class _StatusData {
  final String label;
  final double value;
  final Color color;
  _StatusData(this.label, this.value, this.color);
}
 
