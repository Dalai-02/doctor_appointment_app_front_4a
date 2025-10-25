import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final contactosRef = FirebaseFirestore.instance.collection('contactos');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Contactos Médicos", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: contactosRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay contactos disponibles."));
          }

          final contactos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: contactos.length,
            itemBuilder: (context, index) {
              final data = contactos[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.teal.shade50,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.teal),
                  title: Text(data['nombre'] ?? ''),
                  subtitle: Text(
                    "Especialidad: ${data['especialidad'] ?? ''}\nTel: ${data['telefono'] ?? ''}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.mail_outline, color: Colors.teal),
                    onPressed: () {},
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
