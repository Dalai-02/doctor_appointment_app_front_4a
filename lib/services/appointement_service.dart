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
  // Optional extra fields
  String clinicAddress;
  String instructions;

  Appointment({
    required this.id,
    required this.idMedico,
    required this.idPaciente,
    required this.motivo,
    required this.start,
    required this.end,
    required this.createdBy,
    this.status = 'confirmada',
    this.clinicAddress = '',
    this.instructions = '',
  });

  Map<String, dynamic> toMap() => {
        'id_medico': idMedico,
        'id_paciente': idPaciente,
        'motivo': motivo,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'created_by': createdBy,
        'status': status,
        'clinic_address': clinicAddress,
        'instructions': instructions,
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
      clinicAddress: data['clinic_address'] ?? data['direccion'] ?? '',
      instructions: data['instructions'] ?? data['instrucciones'] ?? '',
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
    // Many compound queries require composite indexes in Firestore.
    // To avoid forcing the developer to create indexes during development,
    // we query by doctor and then filter client-side. This is acceptable for
    // small collections; for production consider creating a composite index
    // for (id_medico ASC, start ASC) and using the server-side query.
    final q = await _col.where('id_medico', isEqualTo: appt.idMedico).get();

    for (final d in q.docs) {
      if (excludeId != null && d.id == excludeId) continue;
      final data = d.data() as Map<String, dynamic>;
      // Guard against missing fields
      if (data['start'] == null || data['end'] == null) continue;
      final existingStart = (data['start'] as Timestamp).toDate();
      final existingEnd = (data['end'] as Timestamp).toDate();
      if (appt.start.isBefore(existingEnd) && appt.end.isAfter(existingStart)) {
        return true;
      }
    }
    return false;
  }

  Future<List<Appointment>> getAppointmentsForUser(String uid) async {
    // Avoid compound query that may require a composite index by
    // querying by id_paciente and sorting client-side.
    final q = await _col.where('id_paciente', isEqualTo: uid).get();
    final list = q.docs.map((d) => Appointment.fromDoc(d)).toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  Future<List<Appointment>> getAppointmentsForDoctor(String idMedico) async {
    // Avoid requiring composite index: query by doctor and sort client-side.
    final q = await _col.where('id_medico', isEqualTo: idMedico).get();
    final list = q.docs.map((d) => Appointment.fromDoc(d)).toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
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

  /// Cancela una cita. Opcionalmente puede incluirse un motivo y el UID
  /// del usuario que realiza la cancelación (por ejemplo el médico).
  Future<void> cancelAppointment(String id, {String? reason, String? cancelledBy}) async {
    final docRef = _col.doc(id);
    final primaryUpdate = <String, dynamic>{
      'status': 'cancelada',
      'cancelled_at': Timestamp.fromDate(DateTime.now()),
    };
    if (reason != null && reason.isNotEmpty) primaryUpdate['cancel_reason'] = reason;
    if (cancelledBy != null && cancelledBy.isNotEmpty) primaryUpdate['cancelled_by'] = cancelledBy;

    try {
      // Intento principal: escribir campos detallados (si las reglas lo permiten)
      await docRef.update(primaryUpdate);
      return;
    } on FirebaseException catch (e) {
      // Si las reglas no permiten estos campos, intentamos una actualización alternativa
      // que sólo modifique campos permitidos por las reglas (status, instructions, clinic_address).
      if (e.code == 'permission-denied') {
        // Leer el documento actual para recuperar instrucciones y concatenar el motivo allí.
        final snap = await docRef.get();
        final data = snap.data() as Map<String, dynamic>?;
        final prevInstructions = (data != null && data['instructions'] != null) ? data['instructions'].toString() : '';
        final buffer = StringBuffer(prevInstructions);
        if (reason != null && reason.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.writeln('Motivo de cancelación (por ${cancelledBy ?? 'doctor'}):');
          buffer.writeln(reason);
        }
        final fallback = <String, dynamic>{
          'status': 'cancelada',
          'instructions': buffer.toString(),
        };
        await docRef.update(fallback);
        return;
      }
      rethrow;
    }
  }

  Future<void> deleteAppointment(String id) async {
    await _col.doc(id).delete();
  }
}
