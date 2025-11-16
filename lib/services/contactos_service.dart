import 'package:cloud_firestore/cloud_firestore.dart';

class Contacto {
  final String id;
  final String nombre;
  final String especialidad;
  final String telefono;
  final String correo;

  Contacto({
    required this.id,
    required this.nombre,
    required this.especialidad,
    required this.telefono,
    required this.correo,
  });

  factory Contacto.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contacto(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      especialidad: data['especialidad'] ?? '',
      telefono: data['telefono'] ?? '',
      correo: data['correo'] ?? '',
    );
  }
}

class ContactosService {
  final _col = FirebaseFirestore.instance.collection('contactos');

  Future<List<Contacto>> getContactos() async {
    final q = await _col.get();
    return q.docs.map((d) => Contacto.fromDoc(d)).toList();
  }
}
