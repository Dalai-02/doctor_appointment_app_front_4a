import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacidad")),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 200));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Text(
                  """Si creas una cuenta de clientes en este sitio web, compilamos la información personal para mejorar nuestra experiencia de finalización de compra y nuestro servicio al cliente.

Esta información puede incluir los siguientes datos personales:

- Direcciones insertadas
- Detalles sobre tus consultas (por ejemplo, tus citas médicas)
- Dirección de correo electrónico
- Nombre
- Número de teléfono

Compartimos esta información con Firestore Database, nuestro proveedor de alojamiento web, para que puedan brindarnos sus servicios. Tus datos están protegidos y se usan solo para gestionar tus citas médicas y recomendaciones de salud.""",
                  textAlign: TextAlign.justify,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
