import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        title: const Text("Inicio"),
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

            // Botones principales
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: [
                _menuButton(context, Icons.calendar_today, "Agendar Cita", Routes.appointments),
                _menuButton(context, Icons.medical_services, "Consejos Médicos", ""),
              ],
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),

            // Consejos saludables
            const Text(
              "Consejos saludables",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            FutureBuilder(
              future: _service.getConsejos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text("No hay consejos disponibles por ahora.");
                }
                final list = snapshot.data!;
                return Column(
                  children: list
                      .map((c) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 2,
                            child: ListTile(
                              leading: const Icon(Icons.health_and_safety, color: Colors.teal),
                              title: Text(c.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(c.descripcion),
                            ),
                          ))
                      .toList(),
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
