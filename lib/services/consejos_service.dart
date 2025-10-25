import 'package:cloud_firestore/cloud_firestore.dart';

class Consejo {
  final String id;
  final String titulo;
  final String descripcion;

  Consejo({required this.id, required this.titulo, required this.descripcion});

  factory Consejo.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Consejo(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
    );
  }
}

class ConsejosService {
  final _col = FirebaseFirestore.instance.collection('consejos');

  Future<List<Consejo>> getConsejos() async {
    final q = await _col.get();
    return q.docs.map((d) => Consejo.fromDoc(d)).toList();
  }
}
