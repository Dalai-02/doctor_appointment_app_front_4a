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

    Future<void> onRefresh() async {
      // Forzar recarga de la lista (puedes mejorar esto con un provider o setState si lo haces stateful)
      (context as Element).markNeedsBuild();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Nota: ahora usamos streams para escuchar citas en tiempo real según el role.

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
      body: Listener(
        onPointerDown: (event) {
          if (event.position.dx < 40) _dragDx = 0.0;
        },
        onPointerMove: (event) {
          if (event.position.dx < 80 && event.delta.dx > 0) _dragDx += event.delta.dx;
        },
        onPointerUp: (event) {
          if (_dragDx > 80.0) {
            Navigator.pushReplacementNamed(context, Routes.home);
          }
          _dragDx = 0.0;
        },
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
            builder: (context, userSnap) {
              if (userSnap.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(child: Text('Error leyendo perfil: ${userSnap.error}', style: const TextStyle(color: Colors.red))),
                  ],
                );
              }
              if (!userSnap.hasData) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))],
                );
              }

              final userData = userSnap.data!.data() as Map<String, dynamic>?;
              final role = (userData?['role'] ?? '').toString().toLowerCase();
              // Detect various ways role may be written: 'Médico', 'Medico', 'doctor', etc.
              final isDoctor = role.contains('med') || role.contains('méd') || role.contains('doctor');
              final citasStream = FirebaseFirestore.instance.collection('citas').where(isDoctor ? 'id_medico' : 'id_paciente', isEqualTo: user.uid).snapshots();

              return StreamBuilder<QuerySnapshot>(
                stream: citasStream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    final err = snap.error;
                    final message = (err is FirebaseException && err.code == 'permission-denied')
                        ? 'Permiso denegado al leer tus citas. Revisa las reglas de Firestore o asegúrate de que el usuario está autenticado.'
                        : 'Error: ${snap.error}';
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Center(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    );
                  }

                  if (!snap.hasData) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))],
                    );
                  }

                  final docs = snap.data!.docs;
                  final list = docs.map((d) => Appointment.fromDoc(d)).toList();
                  if (list.isEmpty) {
                    // DEBUG: mostrar documentos crudos para diagnosticar por qué no aparecen
                    final rawDocs = docs.map((d) => d.data()).toList();
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      children: [
                        const SizedBox(height: 8),
                        const Center(child: Text('No tienes citas programadas')), 
                        const SizedBox(height: 12),
                        const Text('DEBUG: documentos crudos en snapshot (mostrar para diagnóstico):', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...rawDocs.map((d) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.all(8),
                                child: Text(d.toString()),
                              ),
                            )),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                          trailing: a.status.toLowerCase() == 'cancelada'
                              ? const Icon(Icons.cancel, color: Colors.red)
                                  : IconButton(
                                      icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                                      tooltip: 'Cancelar cita',
                                      onPressed: () async {
                                        // If the current user is a doctor, ask for an optional reason (<=150 words)
                                        if (isDoctor) {
                                          final TextEditingController _reasonCtrl = TextEditingController();
                                          String errorText = '';
                                          final result = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) {
                                              return StatefulBuilder(builder: (ctx2, setState2) {
                                                int wordCount(String s) {
                                                  if (s.trim().isEmpty) return 0;
                                                  return s.trim().split(RegExp(r'\s+')).length;
                                                }

                                                return AlertDialog(
                                                  title: const Text('Cancelar cita (opcional)') ,
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Text('Puedes enviar un mensaje (máx. 150 palabras) con el motivo de la cancelación.'),
                                                      const SizedBox(height: 8),
                                                      TextField(
                                                        controller: _reasonCtrl,
                                                        maxLines: 6,
                                                        decoration: InputDecoration(
                                                          hintText: 'Motivo de la cancelación (opcional)',
                                                          errorText: errorText.isEmpty ? null : errorText,
                                                        ),
                                                        onChanged: (v) {
                                                          final wc = wordCount(v);
                                                          if (wc > 150) {
                                                            setState2(() => errorText = 'Has excedido el límite de 150 palabras (actual: $wc)');
                                                          } else {
                                                            if (errorText.isNotEmpty) setState2(() => errorText = '');
                                                          }
                                                          setState2(() {});
                                                        },
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Builder(builder: (ctx3) {
                                                        final wc = wordCount(_reasonCtrl.text);
                                                        return Align(alignment: Alignment.centerLeft, child: Text('Palabras: $wc / 150', style: const TextStyle(fontSize: 12, color: Colors.black54)));
                                                      }),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.of(ctx2).pop(false), child: const Text('Cancelar')),
                                                    TextButton(
                                                      onPressed: () {
                                                        final wc = wordCount(_reasonCtrl.text);
                                                        if (wc > 150) {
                                                          setState2(() => errorText = 'Has excedido el límite de 150 palabras (actual: $wc)');
                                                          return;
                                                        }
                                                        Navigator.of(ctx2).pop(true);
                                                      },
                                                      child: const Text('Enviar y cancelar'),
                                                    ),
                                                  ],
                                                );
                                              });
                                            },
                                          );
                                          if (result != true) return;
                                          final reason = _reasonCtrl.text.trim();
                                          try {
                                            await service.cancelAppointment(a.id, reason: reason.isEmpty ? null : reason, cancelledBy: user.uid);
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita cancelada.')));
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar: ${e.toString()}')));
                                          }
                                        } else {
                                          // non-doctor: simple confirmation
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Cancelar cita'),
                                              content: const Text('¿Estás seguro que deseas cancelar esta cita?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                                                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sí')),
                                              ],
                                            ),
                                          );
                                          if (confirm != true) return;
                                          try {
                                            await service.cancelAppointment(a.id, cancelledBy: user.uid);
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita cancelada.')));
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar: ${e.toString()}')));
                                          }
                                        }
                                      },
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
