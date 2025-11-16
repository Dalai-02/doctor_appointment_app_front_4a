import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isRegister = false;
  bool _loading = false;
  String _selectedRole = 'Paciente';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = emailController.text.trim();
    final pass = passwordController.text;
    setState(() => _loading = true);

    try {
      if (_isRegister) {
        final cred = await _auth.createUserWithEmailAndPassword(email: email, password: pass);
        final user = cred.user!;
        await _firestore.collection('usuarios').doc(user.uid).set({
          'email': user.email,
          'uid': user.uid,
          'role': _selectedRole,
          'nombre': '',
          'telefono': '',
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario creado.')));
      } else {
        final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: pass);
        final uid = userCredential.user!.uid;
        final userDocRef = _firestore.collection('usuarios').doc(uid);
        final doc = await userDocRef.get();

        if (!doc.exists) {
          // Si no existe, crea con el role seleccionado
          await userDocRef.set({
            'email': userCredential.user!.email,
            'uid': uid,
            'role': _selectedRole,
            'nombre': '',
            'telefono': '',
          }, SetOptions(merge: true));
        } else {
          // Si existe y el role es distinto al seleccionado, pide confirmación para cambiarlo
          final currentRole = (doc.data()?['role'] ?? '').toString();
          if (currentRole.toLowerCase() != _selectedRole.toLowerCase()) {
            final change = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cambiar rol de usuario'),
                content: Text('El rol registrado es "$currentRole". ¿Deseas cambiarlo a "$_selectedRole"?'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Si')),
                ],
              ),
            );
            if (change == true) {
              await userDocRef.set({'role': _selectedRole}, SetOptions(merge: true));
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bienvenido ${userCredential.user!.email}")));
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.home);
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Error de autenticación';
      if (e.code == 'user-not-found') message = 'Usuario no encontrado';
      if (e.code == 'wrong-password') message = 'Contraseña incorrecta';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

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
                  // Mode toggle (Login / Registro)
                  ToggleButtons(
                    isSelected: [_isRegister == false, _isRegister == true],
                    onPressed: (i) => setState(() => _isRegister = (i == 1)),
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Login')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Registro')),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 8),
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
                    keyboardType: TextInputType.emailAddress,
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
                  const SizedBox(height: 16),

                  // Selector de rol visible tanto en login como en registro
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        items: const [
                          DropdownMenuItem(value: 'Paciente', child: Text('Paciente')),
                          DropdownMenuItem(value: 'Médico', child: Text('Médico')),
                        ],
                        onChanged: (v) => setState(() => _selectedRole = v ?? 'Paciente'),
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isRegister ? 'Registrar' : 'Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister ? '¿Ya tienes cuenta? Ingresar' : '¿No tienes cuenta? Registrarte'),
                  ),
                  // Hint
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Selecciona tu rol antes de iniciar sesión o registrarte. Si eliges "Médico", en la pantalla principal verás el preview y acceso al Dashboard.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}//sss