import 'package:cloud_firestore/cloud_firestore.dart';

class Consejo {
  final String id;
  final String titulo;
  final String descripcion;
  final String categoria;

  Consejo({required this.id, required this.titulo, required this.descripcion, this.categoria = ''});

  factory Consejo.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Support multiple possible field names used in different documents
    final titulo = data['titulo'] ?? data['title'] ?? data['name'] ?? '';
  final descripcion = data['descripcion'] ?? data['descripción'] ?? data['description'] ?? data['body'] ?? '';
    final categoria = data['categoria'] ?? data['category'] ?? data['categoría'] ?? '';
    return Consejo(
      id: doc.id,
      titulo: titulo,
      descripcion: descripcion,
      categoria: categoria,
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
