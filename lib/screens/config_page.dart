import 'package:flutter/material.dart';
import '../routes.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración"),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Perfil"),
            trailing: const Icon(Icons.person),
            onTap: () => Navigator.pushNamed(context, Routes.profile),
          ),
          ListTile(
            title: const Text("Privacidad"),
            trailing: const Icon(Icons.lock),
            onTap: () => Navigator.pushNamed(context, Routes.privacy),
          ),
          ListTile(
            title: const Text("Sobre nosotros"),
            trailing: const Icon(Icons.info),
            onTap: () => Navigator.pushNamed(context, Routes.about),
          ),
          ListTile(
            title: const Text("Cerrar sesión"),
            trailing: const Icon(Icons.logout),
            onTap: () async {
              await _auth.signOut();
              Navigator.pushReplacementNamed(context, Routes.login);
            },
          ),
        ],
      ),

      // 🔹 Barra inferior igual que en Home
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // Config activo
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, Routes.home);
              break;
            case 1:
              Navigator.pushReplacementNamed(context, Routes.messages);
              break;
            case 2:
              // ya estamos aquí
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "Mensajes"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ajustes"),
        ],
      ),
    );
  }
}
