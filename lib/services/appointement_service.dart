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
  /// Returns: 'updated' if appointment doc was updated,
  /// 'logged' if a citas_canceladas log was created as fallback,
  /// 'already_cancelled' if the appointment was already cancelled,
  /// throws on unexpected errors.
  Future<String> cancelAppointment(String id, {String? reason, String? cancelledBy}) async {
    final docRef = _col.doc(id);
    // Strategy:
    // 1) Try a minimal update (status only) — this is most likely to be allowed by rules.
    // 2) If step 1 succeeds, try to write richer cancellation metadata (cancelled_at, cancelled_by, cancel_reason) separately — ignore permission errors.
    // 3) If step 1 fails with permission-denied, fallback to concatenating the reason into `instructions` if possible.

    // Use a transaction to make the update idempotent and avoid double-cancels.
    try {
      String outcome = 'updated';
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          // If the document no longer exists, treat as already cancelled/missing.
          outcome = 'already_cancelled';
          return;
        }
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final currentStatus = (data['status'] ?? '').toString().toLowerCase();
        if (currentStatus == 'cancelada') {
          outcome = 'already_cancelled';
          return;
        }

        final updateData = <String, dynamic>{
          'status': 'cancelada',
          'cancelled_at': Timestamp.fromDate(DateTime.now()),
        };
        if (cancelledBy != null && cancelledBy.isNotEmpty) updateData['cancelled_by'] = cancelledBy;
        if (reason != null && reason.isNotEmpty) updateData['cancel_reason'] = reason;

        tx.update(docRef, updateData);
      });
      // If we reached here without exception, the transaction succeeded.
      return outcome;
    } on FirebaseException catch (e) {
      // If the transaction was denied due to security rules, attempt fallback logging.
      if (e.code == 'permission-denied') {
        try {
          // Check if a cancellation log already exists for this appointment to avoid duplicates.
          final existing = await FirebaseFirestore.instance
              .collection('citas_canceladas')
              .where('appointment_id', isEqualTo: id)
              .limit(1)
              .get();
          if (existing.docs.isNotEmpty) {
            return 'already_logged';
          }

          final snap = await docRef.get();
          final data = snap.data() as Map<String, dynamic>? ?? {};
          final log = {
            'appointment_id': id,
            'cancelled_by': cancelledBy ?? '',
            'cancel_reason': reason ?? '',
            'cancelled_at': Timestamp.fromDate(DateTime.now()),
            'appointment_snapshot': data,
          };
          await FirebaseFirestore.instance.collection('citas_canceladas').add(log);
          return 'logged';
        } on FirebaseException catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<void> deleteAppointment(String id) async {
    await _col.doc(id).delete();
  }

  /// Método específico para que un médico "borre" una cita dirigida a él.
  /// Implementa un soft-delete por defecto: registra la cancelación (status + campos)
  /// y crea un documento en `citas_canceladas` con el snapshot y el motivo.
  /// Si `forceDelete==true` intentará además eliminar el documento físico (requiere reglas que lo permitan).
  Future<void> doctorDeleteAppointment(String id,
      {required String reason, required String doctorUid, bool forceDelete = false}) async {
    final docRef = _col.doc(id);

    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Cita no encontrada');
    final data = snap.data() as Map<String, dynamic>? ?? {};

    // Verificación básica en cliente: la cita debe dirigirse a este médico
    final idMedico = data['id_medico'] ?? '';
    if (idMedico != doctorUid) {
      throw Exception('No autorizado: la cita no está dirigida a este médico.');
    }

    // 1) Intentar realizar una cancelación controlada (status + metadata)
    final res = await cancelAppointment(id, reason: reason, cancelledBy: doctorUid);

    // 2) Registrar en colección de logs de cancelaciones sólo si la
    // transacción actualizó el documento (para evitar duplicados cuando
    // cancelAppointment ya registró el log como fallback).
    if (res == 'updated') {
      final log = {
        'appointment_id': id,
        'cancelled_by': doctorUid,
        'cancel_reason': reason,
        'cancelled_at': Timestamp.fromDate(DateTime.now()),
        'appointment_snapshot': data,
      };
      await FirebaseFirestore.instance.collection('citas_canceladas').add(log);
    }

    // 3) Opcional: intentar borrar físicamente (no recomendado sin reglas explícitas)
    if (forceDelete) {
      try {
        await docRef.delete();
      } on FirebaseException catch (e) {
        // Si las reglas no permiten el delete, no fallamos: dejamos la cita como 'cancelada'.
        if (e.code == 'permission-denied') {
          return;
        }
        rethrow;
      }
    }
  }
}
