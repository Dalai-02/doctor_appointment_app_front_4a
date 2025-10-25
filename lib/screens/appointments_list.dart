import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/appointement_service.dart';
import '../routes.dart';
import 'appointments_calendar.dart';

class AppointmentsListPage extends StatelessWidget {
  const AppointmentsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final service = AppointmentService();

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
      body: FutureBuilder<List<Appointment>>(
        future: service.getAppointmentsForUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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
                  trailing: IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      Routes.appointmentDetail,
                      arguments: a.id,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, Routes.appointmentForm),
        child: const Icon(Icons.add),
      ),
    );
  }
}
