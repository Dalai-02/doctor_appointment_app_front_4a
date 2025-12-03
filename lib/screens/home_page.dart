import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/consejos_service.dart';
import '../routes.dart';
import '../blocs/dashboard_bloc.dart';
import 'dashboard_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;

  double _dragStartX = 0.0;
  double _dragDx = 0.0;
  bool _draggingFromLeft = false;

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {});
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Seguro que quieres cerrar sesión?'),
        content: const Text('Perderás tu sesión actual y deberás volver a iniciar sesión.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cerrar sesión')),
        ],
      ),
    );

    if (should == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final rectDecoration = BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Doctor Appointment"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                _dragStartX = details.globalPosition.dx;
                _dragDx = 0.0;
                _draggingFromLeft = _dragStartX < 40.0;
              },
              onHorizontalDragUpdate: (details) {
                if (_draggingFromLeft && details.delta.dx > 0) {
                  _dragDx += details.delta.dx;
                }
              },
              onHorizontalDragEnd: (details) async {
                if (_draggingFromLeft && _dragDx > 120.0) {
                  await _confirmLogout(context);
                }
                _dragDx = 0.0;
                _draggingFromLeft = false;
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "¡Hola, ${user?.email?.split('@')[0] ?? 'Usuario'}!",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text("¿En qué podemos ayudarte hoy?"),
                    const SizedBox(height: 20),

                    // Dashboard preview al inicio: si usuario es médico
                    StreamBuilder<DocumentSnapshot>(
                      stream: user == null ? null : FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
                      builder: (context, snap) {
                        final role = (snap.hasData && snap.data!.exists)
                            ? ((snap.data!.data() as Map<String, dynamic>?)?['role'] ?? '').toString().toLowerCase()
                            : '';
                        final isDoctor = role == 'medico' || role == 'médico' || role == 'doctor';
                        if (!isDoctor) return const SizedBox.shrink();

                        return Column(
                          children: [
                            // Preview card (mini indicadores)
                            BlocProvider(
                              create: (_) => DashboardBloc()..add(DashboardStart(user!.uid)),
                              child: Card(
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: BlocBuilder<DashboardBloc, dynamic>(
                                    builder: (context, state) {
                                      if (state is DashboardLoading) {
                                        return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                                      }
                                      if (state is DashboardLoaded) {
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            _miniIndicator(Icons.event, 'Total', state.totalAppointments.toString()),
                                            _miniIndicator(Icons.schedule, 'Próx.', state.upcomingAppointments.toString()),
                                            _miniIndicator(Icons.person, 'Pac.', state.totalPatients.toString()),
                                          ],
                                        );
                                      }
                                      if (state is DashboardError) {
                                        return Center(child: Text('Error: ${state.message}'));
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Tap para abrir Dashboard completo
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider(
                                      create: (_) => DashboardBloc()..add(DashboardStart(user!.uid)),
                                      child: const DashboardPage(),
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                color: Colors.blue.shade50,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 72,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.dashboard, size: 32, color: Colors.blue),
                                        SizedBox(width: 12),
                                        Expanded(child: Text('Abrir Dashboard completo', style: TextStyle(fontSize: 16))),
                                        Icon(Icons.arrow_forward_ios, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),

                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        _menuButton(context, Icons.calendar_today, "Mis Citas", Routes.appointments),
                        _menuButton(context, Icons.event_available, "Agendar Cita", Routes.appointmentForm),
                      ],
                    ),

                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 10),

                    const Text(
                      "Doctores reconocidos",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildDoctoresReconocidos(rectDecoration),

                    const SizedBox(height: 30),
                    const Divider(),

                    const Text(
                      "Consejos saludables",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildConsejos(rectDecoration),

                    const SizedBox(height: 30),
                    const Divider(),

                    const Text(
                      "Contactos recientes",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildContactos(rectDecoration),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 20,
            child: GestureDetector(
              onHorizontalDragEnd: (details) async {
                if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                  await _confirmLogout(context);
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(context, 0),
    );
  }

  Widget _menuButton(BuildContext context, IconData icon, String text, String route) {
    return SizedBox(
      width: 150,
      height: 120,
      child: ElevatedButton(
        onPressed: route.isEmpty ? null : () => Navigator.pushNamed(context, route),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _miniIndicator(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.teal),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, int current) {
    return BottomNavigationBar(
      currentIndex: current,
      onTap: (index) {
        switch (index) {
          case 0:
            break;
          case 1:
            Navigator.pushReplacementNamed(context, Routes.messages);
            break;
          case 2:
            Navigator.pushReplacementNamed(context, Routes.config);
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
        BottomNavigationBarItem(icon: Icon(Icons.message), label: "Mensajes"),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ajustes"),
      ],
    );
  }

  Widget _buildDoctoresReconocidos(BoxDecoration rectDecoration) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('doctores_reconocidos').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text('No hay doctores reconocidos disponibles');
        return Container(
          decoration: rectDecoration,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? data['Nombre'] ?? 'Dr./Dra. Sin nombre';
              final especialidad = data['especialidad'] ?? data['Especialidad'] ?? '';
              final correo = data['email'] ?? '';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.medical_services)),
                  title: Text(nombre),
                  subtitle: Text('$especialidad${correo.isNotEmpty ? '\nEmail: $correo' : ''}'),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildConsejos(BoxDecoration rectDecoration) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('consejos').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text('No hay consejos disponibles');
        return Container(
          decoration: rectDecoration,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: docs.map((doc) {
              final c = Consejo.fromDoc(doc);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(c.titulo),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.descripcion.isNotEmpty) Text(c.descripcion),
                      if (c.categoria.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text('Categoría: ${c.categoria}',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildContactos(BoxDecoration rectDecoration) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('contactos').limit(3).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text('No hay contactos recientes.');
        return Container(
          decoration: rectDecoration,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? data['Nombre'] ?? 'Sin nombre';
              final telefono = data['telefono'] ?? 'No disponible';
              final correo = data['email'] ?? '';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.teal),
                  title: Text(nombre),
                  subtitle: Text(
                    'Tel: $telefono${correo.isNotEmpty ? '\nEmail: $correo' : ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}