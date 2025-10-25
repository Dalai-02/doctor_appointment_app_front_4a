import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  String id;
  String idMedico;
  String idPaciente;
  String motivo;
  DateTime start;
  DateTime end;
  String createdBy;
  String status;

  Appointment({
    required this.id,
    required this.idMedico,
    required this.idPaciente,
    required this.motivo,
    required this.start,
    required this.end,
    required this.createdBy,
    this.status = 'confirmada',
  });

  Map<String, dynamic> toMap() => {
        'id_medico': idMedico,
        'id_paciente': idPaciente,
        'motivo': motivo,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'created_by': createdBy,
        'status': status,
      };

  static Appointment fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      idMedico: data['id_medico'] ?? '',
      idPaciente: data['id_paciente'] ?? '',
      motivo: data['motivo'] ?? '',
      start: (data['start'] as Timestamp).toDate(),
      end: (data['end'] as Timestamp).toDate(),
      createdBy: data['created_by'] ?? '',
      status: data['status'] ?? 'confirmada',
    );
  }
}

class AppointmentService {
  final CollectionReference _col = FirebaseFirestore.instance.collection('citas');

  Future<String> createAppointment(Appointment appt) async {
    // Validate overlaps before creating
    final conflict = await _hasOverlap(appt);
    if (conflict) {
      throw Exception('El horario seleccionado se solapa con otra cita.');
    }
    final docRef = await _col.add(appt.toMap());
    return docRef.id;
  }

  Future<bool> _hasOverlap(Appointment appt, {String? excludeId}) async {
    // Query all citas for same doctor with start < appt.end and end > appt.start
    final q = await _col
        .where('id_medico', isEqualTo: appt.idMedico)
        .where('start', isLessThan: Timestamp.fromDate(appt.end))
        .get();

    for (final d in q.docs) {
      if (excludeId != null && d.id == excludeId) continue;
      final data = d.data() as Map<String, dynamic>;
      final existingStart = (data['start'] as Timestamp).toDate();
      final existingEnd = (data['end'] as Timestamp).toDate();
      if (appt.start.isBefore(existingEnd) && appt.end.isAfter(existingStart)) {
        return true;
      }
    }
    return false;
  }

  Future<List<Appointment>> getAppointmentsForUser(String uid) async {
    final q = await _col.where('id_paciente', isEqualTo: uid).orderBy('start').get();
    return q.docs.map((d) => Appointment.fromDoc(d)).toList();
  }

  Future<List<Appointment>> getAppointmentsForDoctor(String idMedico) async {
    final q = await _col.where('id_medico', isEqualTo: idMedico).orderBy('start').get();
    return q.docs.map((d) => Appointment.fromDoc(d)).toList();
  }

  Future<Appointment> getById(String id) async {
    final doc = await _col.doc(id).get();
    return Appointment.fromDoc(doc);
  }

  Future<void> updateAppointment(Appointment appt) async {
    final conflict = await _hasOverlap(appt, excludeId: appt.id);
    if (conflict) {
      throw Exception('El nuevo horario se solapa con otra cita.');
    }
    await _col.doc(appt.id).update(appt.toMap());
  }

  Future<void> deleteAppointment(String id) async {
    await _col.doc(id).delete();
  }
}
