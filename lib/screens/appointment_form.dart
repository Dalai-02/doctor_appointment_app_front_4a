import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:practica/services/appointement_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppointmentFormPage extends StatefulWidget {
  final Appointment? editing;
  const AppointmentFormPage({super.key, this.editing});

  @override
  State<AppointmentFormPage> createState() => _AppointmentFormPageState();
}

class _AppointmentFormPageState extends State<AppointmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();
  final _patientCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  String _selectedDoctor = ''; // will be populated from 'doctores' collection
  final _service = AppointmentService();

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _motivoCtrl.text = widget.editing!.motivo;
      _start = widget.editing!.start;
      _end = widget.editing!.end;
      _selectedDoctor = widget.editing!.idMedico;
      _patientCtrl.text = widget.editing!.idPaciente;
      _instructionsCtrl.text = widget.editing!.instructions;
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? (_start ?? DateTime.now()) : (_end ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? (_start ?? DateTime.now()) : (_end ?? DateTime.now())),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) _start = dt;
      else _end = dt;
    });
  }

  String _fmt(DateTime? d) => d == null ? 'Seleccionar' : DateFormat('yyyy-MM-dd HH:mm').format(d);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona fecha y hora de inicio y fin')));
      return;
    }
    if (!_start!.isBefore(_end!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La hora de inicio debe ser antes de la hora de fin')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    final appt = Appointment(
      id: widget.editing?.id ?? '',
      idMedico: _selectedDoctor,
      idPaciente: _patientCtrl.text.isNotEmpty ? _patientCtrl.text : user.uid,
      motivo: _motivoCtrl.text.trim(),
      start: _start!,
      end: _end!,
      createdBy: user.uid,
      status: 'confirmada',
      clinicAddress: '',
      instructions: _instructionsCtrl.text.trim(),
    );

    try {
      if (widget.editing == null) {
        await _service.createAppointment(appt);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita creada')));
      } else {
        appt.id = widget.editing!.id;
        await _service.updateAppointment(appt);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita actualizada')));
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _patientCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing == null ? 'Crear Cita' : 'Editar Cita')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Motivo
              TextFormField(
                controller: _motivoCtrl,
                decoration: const InputDecoration(labelText: 'Motivo de la consulta'),
                validator: (v) => v == null || v.isEmpty ? 'Introduce un motivo' : null,
              ),
              const SizedBox(height: 12),

              // Doctor - load dynamically from Firestore
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('doctores').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: LinearProgressIndicator(),
                    );
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Text('No hay especialistas disponibles');
                  }
                  // ensure a selected value exists
                  if (_selectedDoctor.isEmpty) {
                    // prefer existing editing value (already set in initState), otherwise pick first
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedDoctor = docs.first.id);
                    });
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedDoctor.isNotEmpty ? _selectedDoctor : docs.first.id,
                    items: docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final nombre = data['nombre'] ?? data['Nombre'] ?? data['name'] ?? 'Dr./Dra. Sin nombre';
                      final especialidad = data['especialidad'] ?? data['Especialidad'] ?? '';
                      return DropdownMenuItem(value: d.id, child: Text('$nombre ${especialidad.isNotEmpty ? '- $especialidad' : ''}'));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedDoctor = v ?? ''),
                    decoration: const InputDecoration(labelText: 'Especialista'),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Opcional: paciente UID (permite asignar a un paciente diferente)
              TextFormField(
                controller: _patientCtrl,
                decoration: const InputDecoration(labelText: 'Paciente (UID) - opcional'),
              ),
              const SizedBox(height: 12),

              // (Dirección clínica eliminada por solicitud)
              const SizedBox(height: 12),

              // Opcional: instrucciones previas
              TextFormField(
                controller: _instructionsCtrl,
                decoration: const InputDecoration(labelText: 'Instrucciones (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDateTime(isStart: true),
                      child: Text('Inicio: ${_fmt(_start)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDateTime(isStart: false),
                      child: Text('Fin: ${_fmt(_end)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
  }
}
