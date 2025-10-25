import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentDetailPage extends StatelessWidget {
  final String appointmentId;

  const AppointmentDetailPage({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    final citasRef =
        FirebaseFirestore.instance.collection('citas').doc(appointmentId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de Cita"),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: citasRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No se encontró la cita."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.teal.shade50,
              elevation: 3,
              child: ListTile(
                title: Text("Motivo: ${data['motivo'] ?? 'Sin motivo'}"),
                subtitle: Text(
                  "Fecha: ${data['fecha'] ?? ''}\n"
                  "Inicio: ${data['hora_inicio'] ?? ''}\n"
                  "Fin: ${data['hora_fin'] ?? ''}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    await citasRef.delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Cita eliminada.")),
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
