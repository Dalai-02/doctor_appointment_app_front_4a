import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/appointement_service.dart';
import 'appointment_form.dart';

class AppointmentDetailPage extends StatelessWidget {
  final String appointmentId;

  const AppointmentDetailPage({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    final service = AppointmentService();
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Cita'),
      ),
      body: FutureBuilder<Appointment>(
        future: service.getById(appointmentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Cita no encontrada'));
          }

          final a = snapshot.data!;

          // Also fetch doctor and patient basic info (if available)
          final doctorFuture = FirebaseFirestore.instance.collection('doctores').doc(a.idMedico).get();
          final patientFuture = FirebaseFirestore.instance.collection('usuarios').doc(a.idPaciente).get();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.teal.shade50,
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Motivo: ${a.motivo}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Inicio: ${fmt.format(a.start)}'),
                    Text('Fin: ${fmt.format(a.end)}'),
                    const SizedBox(height: 8),
                    if (a.clinicAddress.isNotEmpty) Text('Dirección: ${a.clinicAddress}'),
                    if (a.instructions.isNotEmpty) Text('Instrucciones: ${a.instructions}'),
                    const SizedBox(height: 12),

                    FutureBuilder<DocumentSnapshot>(
                      future: doctorFuture,
                      builder: (context, dsnap) {
                        if (!dsnap.hasData || !dsnap.data!.exists) return const SizedBox.shrink();
                        final d = dsnap.data!.data() as Map<String, dynamic>;
                        final nombre = d['nombre'] ?? d['name'] ?? 'Dr./Dra. sin nombre';
                        final direccion = d['direccion'] ?? d['direccion_clinica'] ?? '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text('Médico: $nombre', style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (direccion.isNotEmpty) Text('Dirección clínica: $direccion'),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    FutureBuilder<DocumentSnapshot>(
                      future: patientFuture,
                      builder: (context, psnap) {
                        if (!psnap.hasData || !psnap.data!.exists) return const SizedBox.shrink();
                        final p = psnap.data!.data() as Map<String, dynamic>;
                        final pname = p['nombre'] ?? p['name'] ?? p['email'] ?? 'Paciente';
                        return Text('Paciente: $pname');
                      },
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar'),
                          onPressed: () {
                            // Open form in edit mode directly with the Appointment object
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AppointmentFormPage(editing: a)),
                            ).then((_) => Navigator.pop(context));
                          },
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirmar eliminación'),
                                content: const Text('¿Deseas eliminar esta cita? Esta acción no se puede deshacer.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await service.deleteAppointment(a.id);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita eliminada.')));
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
