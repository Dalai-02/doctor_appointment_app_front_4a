import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/consejos_service.dart';
import '../routes.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  final _service = ConsejosService();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Doctor Appointment"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "¡Hola, ${user?.email?.split('@')[0] ?? 'Usuario'}!",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text("¿En qué podemos ayudarte hoy?"),
            const SizedBox(height: 20),

            // Botones principales: Mis Citas + Agendar
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: [
                _menuButton(context, Icons.calendar_today, "Mis Citas", Routes.appointments),
                _menuButton(context, Icons.event_available, "Agendar Cita", Routes.appointmentForm),
              ],
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),

            // Doctores reconocidos
              const Text(
                "Doctores reconocidos",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('doctores_reconocidos').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Text('No hay doctores reconocidos disponibles');
                  return Column(
                    children: docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final nombre = data['nombre'] ?? data['Nombre'] ?? data['name'] ?? 'Dr./Dra. Sin nombre';
                      final especialidad = data['especialidad'] ?? data['Especialidad'] ?? data['especialidad_medica'] ?? '';
                      final correo = data['Email'] ?? data['email'] ?? data['correo'] ?? '';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.medical_services)),
                          title: Text(nombre),
                          subtitle: Text('$especialidad${correo.isNotEmpty ? '\nEmail: $correo' : ''}'),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            const SizedBox(height: 20),

            // Consejos saludables
            const Text(
              "Consejos saludables",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Consejo>>(
              future: _service.getConsejos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) return const Text('No hay consejos disponibles');
                return Column(
                  children: list.map((c) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(c.titulo),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (c.descripcion.isNotEmpty) Text(c.descripcion),
                          if (c.categoria.isNotEmpty) Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text('Categoría: ${c.categoria}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // Contactos recientes
            const Text(
              "Contactos recientes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('contactos').limit(3).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('No hay contactos recientes.');

                String _find(Map<String, dynamic> m, List<String> keys) {
                  // normalize helper: remove spaces and punctuation and lowercase, strip common accents
                  String normalize(String s) {
                    var r = s.toLowerCase();
                    // simple accent replacements
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
                  // fallback to direct contains
                  for (final k in keys) {
                    if (m.containsKey(k)) return (m[k] ?? '').toString();
                  }
                  return '';
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nombre = _find(data, ['nombre', 'Nombre', 'name', 'displayName']);
                    final especialidad = _find(data, ['especialidad', 'Especialidad', 'especialidad_medica']);
                    final telefono = _find(data, ['telefono', 'tel', 'teléfono', 'Teléfono', 'telefono_', 'telefono']);
                    final correo = _find(data, ['Email', 'email', 'correo', 'Correo']);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.teal),
                        title: Text(nombre.isNotEmpty ? nombre : 'Sin nombre'),
                        subtitle: Text(
                          '${especialidad.isNotEmpty ? '$especialidad\n' : ''}Tel: ${telefono.isNotEmpty ? telefono : 'No disponible'}${correo.isNotEmpty ? '\nEmail: $correo' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(context, 0),
    );
  }

  Widget _menuButton(BuildContext context, IconData icon, String text, String route) {
    return SizedBox(
      width: 150,
      height: 120,
      child: ElevatedButton(
        onPressed: route.isEmpty ? null : () => Navigator.pushNamed(context, route),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, int current) {
    return BottomNavigationBar(
      currentIndex: current,
      onTap: (index) {
        switch (index) {
          case 0:
            break;
          case 1:
            Navigator.pushReplacementNamed(context, Routes.messages);
            break;
          case 2:
            Navigator.pushReplacementNamed(context, Routes.config);
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
        BottomNavigationBarItem(icon: Icon(Icons.message), label: "Mensajes"),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ajustes"),
      ],
    );
  }
}
