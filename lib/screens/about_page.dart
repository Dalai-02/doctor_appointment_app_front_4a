import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sobre Nosotros")),
      body: RefreshIndicator(
        onRefresh: () async {
          // nothing dynamic to reload here, but allow the gesture to provide feedback
          await Future.delayed(const Duration(milliseconds: 200));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text("DoctorAppointmentApp — versión de prueba creada por estudiantes de Ingeniería en Software."),
          ),
        ),
      ),
    );
  }
}
