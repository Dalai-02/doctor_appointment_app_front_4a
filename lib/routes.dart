import 'package:flutter/material.dart';

// Pantallas principales
import 'package:practica/screens/login_page.dart';
import 'package:practica/screens/home_page.dart';
import 'package:practica/screens/profile_page.dart';
import 'package:practica/screens/message_page.dart';
import 'package:practica/screens/config_page.dart';
import 'package:practica/screens/about_page.dart';
import 'package:practica/screens/privacy_page.dart';
import 'package:practica/screens/dashboard_page.dart'; // nuevo

// Pantallas del CRUD de citas
import 'package:practica/screens/appointments_list.dart';
import 'package:practica/screens/appointment_form.dart';
import 'package:practica/screens/appointment_detail.dart';

class Routes {
  // --- Rutas principales ---
  static const String login = '/login';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String messages = '/messages';
  static const String config = '/config';
  static const String about = '/about';
  static const String privacy = '/privacy';
  static const String dashboard = '/dashboard';

  // --- Rutas del CRUD ---
  static const String appointments = '/appointments';
  static const String appointmentForm = '/appointment_form';
  static const String appointmentDetail = '/appointment_detail';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case messages:
        return MaterialPageRoute(builder: (_) => const MessagesPage());
      case config:
        return MaterialPageRoute(builder: (_) => const ConfigPage());
      case about:
        return MaterialPageRoute(builder: (_) => const AboutPage());
      case privacy:
        return MaterialPageRoute(builder: (_) => const PrivacyPage());
      case appointments:
        return MaterialPageRoute(builder: (_) => const AppointmentsListPage());
      case appointmentForm:
        return MaterialPageRoute(builder: (_) => const AppointmentFormPage());
        case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardPage());
      case appointmentDetail:
        // Si no pasas argumentos, usa una página vacía segura
        final id = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => AppointmentDetailPage(appointmentId: id),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("Ruta no definida")),
            body: Center(
              child: Text('No existe la ruta: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
