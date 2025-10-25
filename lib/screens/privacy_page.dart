import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacidad")),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "Tus datos están protegidos y se usan solo para gestionar tus citas médicas y recomendaciones de salud.",
        ),
      ),
    );
  }
}
