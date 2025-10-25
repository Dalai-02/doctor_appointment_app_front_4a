import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes.dart';

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
        // explicit back to Home to avoid route-not-found when using replacement navigation
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, Routes.home),
        ),
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
              // robust extractor to handle accented keys, capitalization, trailing spaces, etc.
              String _find(Map<String, dynamic> m, List<String> keys) {
                String normalize(String s) {
                  var r = s.toLowerCase();
                  r = r.replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n');
                  r = r.replaceAll(RegExp(r'[\s:_\-]+'), '');
                  r = r.replaceAll(RegExp(r'[^a-z0-9]'), '');
                  return r;
                }
                for (final key in m.keys) {
                  final kn = normalize(key.toString());
                  for (final k in keys) {
                    if (kn == normalize(k)) return (m[key] ?? '').toString();
                  }
                }
                for (final k in keys) {
                  if (m.containsKey(k)) return (m[k] ?? '').toString();
                }
                return '';
              }

              final nombre = _find(data, ['nombre', 'Nombre', 'name', 'displayName']);
              final especialidad = _find(data, ['especialidad', 'Especialidad', 'especialidad_medica']);
              final telefono = _find(data, ['telefono', 'tel', 'teléfono', 'Teléfono ', 'Telefono', 'Teléfono']);
              final correo = _find(data, ['correo', 'email', 'Email']);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.teal.shade50,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.teal),
                  title: Text(nombre),
                  subtitle: Text(
                    "Especialidad: $especialidad\nTel: $telefono${correo.isNotEmpty ? '\nEmail: $correo' : ''}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.mail_outline, color: Colors.teal),
                    onPressed: () {
                      if (correo.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Abrir cliente de correo para: $correo')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No hay correo disponible para este contacto')),
                        );
                      }
                    },
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
