import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DoctorAppointmentApp"), automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const SizedBox(height: 8),
              // user icon with a small chat bubble
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircleAvatar(radius: 36, backgroundColor: Colors.teal, child: Icon(Icons.person, size: 36, color: Colors.white)),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.chat_bubble, size: 14, color: Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Correo electrónico",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Por favor ingresa tu correo";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Por favor ingresa tu contraseña";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Botón para INICIAR SESIÓN
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );
                      
                      // Mensaje de Bienvenida
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Bienvenido ${userCredential.user!.email}")),
                      );

                      // Navegación a la página principal
                      Navigator.pushReplacementNamed(context, Routes.home); // Reemplaza la ruta actual
                    } on FirebaseAuthException catch (e) {
                      String message = "";
                      if (e.code == 'user-not-found') {
                        message = "Usuario no encontrado";
                      } else if (e.code == 'wrong-password') {
                        message = "Contraseña incorrecta";
                      } else {
                        message = e.message ?? "Error desconocido";
                      }
                      
                      // Muestra el mensaje de error
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                  }
                },
                child: const Text("Iniciar sesión"),
              ),
              const SizedBox(height: 16),
              
              // (Cerrar sesión eliminado del formulario de login - no es necesario aquí)
            ],
              ), // Column
            ), // Form
          ), // ConstrainedBox
        ), // SingleChildScrollView
      ), // Center
    );
  }
}