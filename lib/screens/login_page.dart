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
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController especialidadController = TextEditingController();
  final TextEditingController passwordConfirmController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isRegister = false;
  bool _loading = false;
  String _selectedRole = 'Paciente';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = emailController.text.trim();
    final pass = passwordController.text;
    // Validación básica de formato de email antes de llamar a Firebase
    bool isValidEmail(String e) {
      // simple regex: contains @ and a dot after @
      final at = e.indexOf('@');
      if (at <= 0) return false;
      final domain = e.substring(at + 1);
      if (!domain.contains('.') || domain.startsWith('.') || domain.endsWith('.')) return false;
      return true;
    }

    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correo electrónico con formato incorrecto')));
      return;
    }
    setState(() => _loading = true);

    try {
      // Debug: imprimir información antes de autenticarse
      // (útil para diagnosticar cuentas médicas con problemas de credenciales)
      // Nota: evita imprimir contraseñas en producción. Aquí solo para depuración local.
      print('Auth attempt: isRegister=$_isRegister, email=$email, role=$_selectedRole');
  if (_isRegister) {
        // Validar nombre y confirmación de contraseña en modo registro
        final nombre = nombreController.text.trim();
        final especialidad = especialidadController.text.trim();
        final passConfirm = passwordConfirmController.text;
        if (nombre.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor ingresa tu nombre')));
          return;
        }
        if (_selectedRole.toLowerCase() == 'médico' || _selectedRole.toLowerCase() == 'medico') {
          if (especialidad.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor ingresa tu especialidad')));
            return;
          }
        }

        if (passConfirm != pass) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
          return;
        }

        final cred = await _auth.createUserWithEmailAndPassword(email: email, password: pass);
        final user = cred.user!;

        // Actualizar displayName del usuario en Firebase Auth
        try {
          await user.updateDisplayName(nombre);
          await user.reload();
        } catch (_) {}

        // Crear documento de usuario. Teléfono y enfermedades se gestionan solo desde ProfilePage.
        await _firestore.collection('usuarios').doc(user.uid).set({
          'email': user.email,
          'uid': user.uid,
          'role': _selectedRole,
          'nombre': nombre,
          'telefono': '',
          'enfermedades': '',
        }, SetOptions(merge: true));
        
        // If the new user is a doctor, create a 'doctores' document so they appear
        // in the specialists list when patients create appointments.
        if (_selectedRole.toLowerCase() == 'médico' || _selectedRole.toLowerCase() == 'medico') {
          try {
            await _firestore.collection('doctores').doc(user.uid).set({
              'nombre': nombre,
              'especialidad': especialidad,
              'email': user.email ?? '',
            }, SetOptions(merge: true));
          } catch (e) {
            // Non-fatal: log and continue. UI already shows user created.
            print('Error creating doctor doc: $e');
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario creado.')));
      } else {
        // Check which sign-in methods exist for this email to give better guidance
        try {
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          print('Sign-in methods for $email: $methods');
          // If no methods are returned, do not block — try sign-in anyway (restore previous behavior)
          // but still detect Google-only accounts and advise the user.
          if (methods.isNotEmpty) {
            final usesGoogle = methods.contains('google.com');
            final usesPassword = methods.contains('password');
            if (usesGoogle && !usesPassword) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta cuenta está registrada con Google. Inicia sesión con Google o vincula una contraseña desde la cuenta.')));
              return;
            }
          } else {
            // methods empty: log and continue to attempt sign-in (fallback)
            print('fetchSignInMethodsForEmail returned empty for $email — attempting sign-in anyway');
          }
        } catch (e) {
          // ignore and proceed to try sign in; any error will be handled below
          print('fetchSignInMethodsForEmail failed: $e');
        }

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
      // Mostrar código y mensaje para diagnóstico (más explícito que antes)
      final code = e.code;
      final msg = e.message ?? '';
      print('FirebaseAuthException: code=$code, message=$msg');

      String userMessage = 'Error de autenticación';
      // Mapear errores comunes a mensajes amigables
      if (code == 'user-not-found') userMessage = 'Usuario no encontrado';
      else if (code == 'wrong-password') userMessage = 'Contraseña incorrecta';
      else if (code == 'invalid-email') userMessage = 'Correo inválido';
      else if (code == 'user-disabled') userMessage = 'Cuenta deshabilitada';
      else if (code == 'invalid-credential') userMessage = 'Credenciales mal formadas o expiradas';
      else userMessage = '$userMessage: $code';

      // Mostrar snackbar con mensaje amigable y opcional detalle en consola
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage)));
      print('Auth failure detail: $msg');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa tu correo para enviar el reset de contraseña')));
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correo de restablecimiento enviado')));
    } on FirebaseAuthException catch (e) {
      print('sendPasswordResetEmail failed: ${e.code} ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar reset: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nombreController.dispose();
    especialidadController.dispose();
    passwordConfirmController.dispose();
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
                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Por favor ingresa tu contraseña";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campos adicionales que solo se muestran en modo Registro
                  if (_isRegister) ...[
                    TextFormField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: "Nombre completo",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (_isRegister && (value == null || value.trim().isEmpty)) {
                          return 'Por favor ingresa tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Especialidad solo visible si el rol seleccionado es Médico
                    if (_selectedRole.toLowerCase() == 'médico' || _selectedRole.toLowerCase() == 'medico') ...[
                      TextFormField(
                        controller: especialidadController,
                        decoration: const InputDecoration(
                          labelText: "Especialidad",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_isRegister && (_selectedRole.toLowerCase() == 'médico' || _selectedRole.toLowerCase() == 'medico') && (value == null || value.trim().isEmpty)) {
                            return 'Por favor ingresa tu especialidad';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: passwordConfirmController,
                      decoration: InputDecoration(
                        labelText: "Confirmar contraseña",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      obscureText: _obscureConfirm,
                      validator: (value) {
                        if (_isRegister && (value == null || value.isEmpty)) {
                          return 'Por favor confirma tu contraseña';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

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
                  if (!_isRegister)
                    TextButton(
                      onPressed: _sendPasswordReset,
                      child: const Text('Olvidé mi contraseña'),
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