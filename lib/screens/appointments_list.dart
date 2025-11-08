import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/appointement_service.dart';
import '../routes.dart';
import 'appointments_calendar.dart';
import 'package:practica/screens/appointment_form.dart';

class AppointmentsListPage extends StatelessWidget {
  static double _dragDx = 0.0;
  const AppointmentsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final service = AppointmentService();

    Future<void> _onRefresh() async {
      // Forzar recarga de la lista (puedes mejorar esto con un provider o setState si lo haces stateful)
      (context as Element).markNeedsBuild();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis citas')),
        body: const Center(child: Text('Necesitas iniciar sesión')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis citas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentsCalendarPage()),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          if (details.globalPosition.dx < 40) _dragDx = 0.0;
        },
        onHorizontalDragUpdate: (details) {
          if (details.globalPosition.dx < 40 && details.delta.dx > 0) _dragDx += details.delta.dx;
        },
        onHorizontalDragEnd: (details) {
          if (_dragDx > 80.0) {
            Navigator.pushReplacementNamed(context, Routes.home);
          }
          _dragDx = 0.0;
        },
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: FutureBuilder<List<Appointment>>(
            future: service.getAppointmentsForUser(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: [38;5;9m${snapshot.error}[0m'));
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('No tienes citas programadas'));
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final a = list[index];
                  final fmt = DateFormat('yyyy-MM-dd HH:mm');
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: ListTile(
                      title: Text(a.motivo),
                      subtitle: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('doctores').doc(a.idMedico).get(),
                        builder: (context, docSnap) {
                          final base = 'Inicio: ${fmt.format(a.start)}\nFin: ${fmt.format(a.end)}';
                          if (!docSnap.hasData || docSnap.data == null) {
                            return Text(base);
                          }
                          final ddata = docSnap.data!.data() as Map<String, dynamic>?;
                          if (ddata == null) return Text(base);
                          final doctorName = ddata['nombre'] ?? ddata['Nombre'] ?? ddata['name'] ?? 'Dr./Dra. Sin nombre';
                          final especial = ddata['especialidad'] ?? ddata['Especialidad'] ?? ddata['especialidad_medica'] ?? '';
                          return Text('$base\nDoctor: $doctorName${especial.isNotEmpty ? ' - $especial' : ''}');
                        },
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.pushNamed(
                        context,
                        Routes.appointmentDetail,
                        arguments: a.id,
                      ),
                      onLongPress: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AppointmentFormPage(editing: a)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, Routes.appointmentForm),
        child: const Icon(Icons.add),
      ),
    );
  }
}
