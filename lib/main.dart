import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'DoctorAppointmentApp',
  theme: ThemeData(
    scaffoldBackgroundColor: const Color(0xFFF7FAFC), // fondo blanco azulado
    primaryColor: const Color(0xFF0077B6), // azul principal
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00B4D8), // azul claro verdoso
      primary: const Color(0xFF0077B6),
      secondary: const Color(0xFF90E0EF),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0077B6),
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00B4D8),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF00B4D8)),
      ),
      labelStyle: TextStyle(color: Color(0xFF0077B6)),
    ),
  ),
  initialRoute: Routes.login,
  onGenerateRoute: Routes.generateRoute,
);

  }
}
