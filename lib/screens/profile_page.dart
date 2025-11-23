import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  double _dragDx = 0.0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController enfermedadesController = TextEditingController();

  bool _loading = false; 

  @override
  void initState() {
    super.initState();
    _loadUserData(); 
  }

  // Carga datos del usuario desde Firestore usando su UID como ID de documento
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        nombreController.text = data?['nombre'] ?? '';
        telefonoController.text = data?['telefono'] ?? '';
        enfermedadesController.text = data?['enfermedades'] ?? '';
      }
    } on FirebaseException catch (e) {
      // Handle permission denied or other Firestore errors gracefully
      final code = e.code;
      print('Error loading user data: $code ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cargar el perfil: $code')));
    } catch (e) {
      print('Unexpected error loading user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cargar perfil')));
    }
  }

  // Guarda o actualiza los datos del usuario
  Future<void> _saveUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión para guardar tu perfil')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': nombreController.text.trim(),
        'telefono': telefonoController.text.trim(),
        'enfermedades': enfermedadesController.text.trim(),
        'email': user.email,
        'uid': user.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información guardada exitosamente')),
      );
    } on FirebaseException catch (e) {
      print('Error saving user data: ${e.code} ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el perfil: ${e.code}')));
    } catch (e) {
      print('Unexpected error saving user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar perfil')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No has iniciado sesión.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, Routes.login),
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Perfil")),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          if (details.globalPosition.dx < 40) _dragDx = 0.0;
        },
        onHorizontalDragUpdate: (details) {
          if (details.globalPosition.dx < 40 && details.delta.dx > 0) _dragDx += details.delta.dx;
        },
        onHorizontalDragEnd: (details) {
          if (_dragDx > 80.0) {
            Navigator.pushReplacementNamed(context, Routes.home);
          }
          _dragDx = 0.0;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUserData();
            setState(() {});
          },
          child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Text(
                      "Correo: ${user.email ?? 'No disponible'}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),

                    // FORMULARIO
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre completo'),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: telefonoController,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: enfermedadesController,
                      decoration: const InputDecoration(labelText: 'Enfermedades'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Botón para GUARDAR información
                    ElevatedButton(
                      onPressed: _saveUserData,
                      child: const Text("Guardar información"),
                    ),
                    const SizedBox(height: 30),

                    // Botón para volver al menú principal
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, Routes.home);
                      },
                      child: const Text("Volver al Menú Principal"),
                    ),
                    const SizedBox(height: 20),

                    // Botón para cerrar sesión
                    ElevatedButton(
                      onPressed: () async {
                        await _auth.signOut();
                        Navigator.pushReplacementNamed(context, Routes.login);
                      },
                      child: const Text("Cerrar sesión"),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}