import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../blocs/dashboard_bloc.dart';
import '../routes.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Médico')),
      body: RefreshIndicator(
        onRefresh: () async {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) context.read<DashboardBloc>().add(DashboardStart(uid));
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            BlocBuilder<DashboardBloc, dynamic>(
              builder: (context, state) {
            if (state is DashboardLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is DashboardError) {
              return Center(child: Text('Error: ${state.message}'));
            }
            if (state is DashboardLoaded) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resumen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _indicatorCard(Icons.event_available, 'Total citas', state.totalAppointments.toString(), Colors.blue),
                      _indicatorCard(Icons.schedule, 'Citas próximas', state.upcomingAppointments.toString(), Colors.orange),
                      _indicatorCard(Icons.person, 'Pacientes registrados', state.totalPatients.toString(), Colors.green),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, Routes.graphics),
                    icon: const Icon(Icons.show_chart),
                    label: const Text('Ver gráficas'),
                  ),
                  // espacio para información extendida o gráficos (frontend mock)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Actividad reciente', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('- Vista preliminar de citas y pacientes (mock/front)'),
                          Text('- Aquí podrías mostrar gráficos o listas filtradas'),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicatorCard(IconData icon, String label, String value, Color color) {
    return SizedBox(
      width: 160,
      child: Card(
        color: color.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}