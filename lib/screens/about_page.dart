import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sobre Nosotros")),
      body: const Center(
        child: Text("DoctorAppointmentApp — versión de prueba creada por estudiantes de Ingeniería en Software."),
      ),
    );
  }
}
