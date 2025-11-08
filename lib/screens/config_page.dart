import 'package:flutter/material.dart';
import '../routes.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  double _dragDx = 0.0;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración"),
        automaticallyImplyLeading: false,
      ),
      body: Listener(
        onPointerDown: (event) {
          if (event.position.dx < 40) _dragDx = 0.0;
        },
        onPointerMove: (event) {
          if (event.position.dx < 80 && event.delta.dx > 0) _dragDx += event.delta.dx;
        },
        onPointerUp: (event) {
          if (_dragDx > 40.0) {
            Navigator.pushReplacementNamed(context, '/home');
          }
          _dragDx = 0.0;
        },
        child: RefreshIndicator(
          notificationPredicate: (notification) => notification.depth == 0,
          onRefresh: _onRefresh,
          child: ListView(
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
                  // Cierre de sesión manual desde el botón
                  await _auth.signOut();
                  Navigator.pushReplacementNamed(context, Routes.login);
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // Ajustes activo
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
