import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class DashboardEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class DashboardStart extends DashboardEvent {
  final String userId;
  DashboardStart(this.userId);
  @override
  List<Object?> get props => [userId];
}

class DashboardStop extends DashboardEvent {}

abstract class DashboardState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final int totalAppointments;
  final int upcomingAppointments;
  final int totalPatients;
  DashboardLoaded({
    required this.totalAppointments,
    required this.upcomingAppointments,
    required this.totalPatients,
  });
  @override
  List<Object?> get props => [totalAppointments, upcomingAppointments, totalPatients];
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  StreamSubscription<QuerySnapshot>? _citasSub;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardBloc() : super(DashboardLoading()) {
    on<DashboardStart>(_onStart);
    on<DashboardStop>(_onStop);
    on<_CitasUpdated>(_onCitasUpdated);
    on<_PatientsUpdated>(_onPatientsUpdated);
    on<_DashboardStreamError>(_onStreamError);
  }

  Future<void> _onStart(DashboardStart event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      // Listen citas for this doctor
      _citasSub = _firestore
          .collection('citas')
          .where('id_medico', isEqualTo: event.userId)
          .snapshots()
          .listen((snap) {
        try {
          final now = DateTime.now();
          final all = snap.docs;
          final total = all.length;
          final upcoming = all.where((d) {
            final data = d.data();
            final start = data['start'];
            if (start == null) return false;
            final startDt = (start as Timestamp).toDate();
            return startDt.isAfter(now);
          }).length;
          // Compute unique patients from citas (avoid reading full usuarios collection)
          final patientsSet = <String>{};
          for (final d in all) {
            final data = d.data();
            final pid = (data['id_paciente'] ?? '').toString();
            if (pid.isNotEmpty) patientsSet.add(pid);
          }
          final patientsCount = patientsSet.length;
          // For patients count we listen separately below and combine when available.
          // Emit partial if users subscription not ready
          add(_CitasUpdated(total, upcoming));
          add(_PatientsUpdated(patientsCount));
        } catch (e) {
          // Dispatch an internal error event so it is handled by the bloc
          add(_DashboardStreamError('Error procesando citas: ${e.toString()}'));
        }
      }, onError: (err) {
        add(_DashboardStreamError('Error en stream de citas: ${err.toString()}'));
      });

      // Note: reading the full 'usuarios' collection may be blocked by Firestore rules
      // (clients typically cannot list all users). Instead we compute the number of
      // distinct pacientes based on the citas stream above (unique id_paciente).
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  void _onStop(DashboardStop event, Emitter<DashboardState> emit) {
    _citasSub?.cancel();
  }

  // Handlers for private internal events
  void _onCitasUpdated(_CitasUpdated event, Emitter<DashboardState> emit) {
    final current = state is DashboardLoaded ? state as DashboardLoaded : DashboardLoaded(totalAppointments: 0, upcomingAppointments: 0, totalPatients: 0);
    emit(DashboardLoaded(
      totalAppointments: event.total,
      upcomingAppointments: event.upcoming,
      totalPatients: current.totalPatients,
    ));
  }

  void _onPatientsUpdated(_PatientsUpdated event, Emitter<DashboardState> emit) {
    final current = state is DashboardLoaded ? state as DashboardLoaded : DashboardLoaded(totalAppointments: 0, upcomingAppointments: 0, totalPatients: 0);
    emit(DashboardLoaded(
      totalAppointments: current.totalAppointments,
      upcomingAppointments: current.upcomingAppointments,
      totalPatients: event.patients,
    ));
  }

  void _onStreamError(_DashboardStreamError event, Emitter<DashboardState> emit) {
    emit(DashboardError(event.message));
  }

  @override
  Future<void> close() {
    _citasSub?.cancel();
    return super.close();
  }
}

// Private helper internal events (as DashboardEvent subclasses)
class _CitasUpdated extends DashboardEvent {
  final int total;
  final int upcoming;
  _CitasUpdated(this.total, this.upcoming);

  @override
  List<Object?> get props => [total, upcoming];
}

class _PatientsUpdated extends DashboardEvent {
  final int patients;
  _PatientsUpdated(this.patients);

  @override
  List<Object?> get props => [patients];
}

class _DashboardStreamError extends DashboardEvent {
  final String message;
  _DashboardStreamError(this.message);

  @override
  List<Object?> get props => [message];
}