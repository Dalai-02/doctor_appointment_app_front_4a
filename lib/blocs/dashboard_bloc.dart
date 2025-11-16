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
  StreamSubscription<QuerySnapshot>? _usersSub;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardBloc() : super(DashboardLoading()) {
    on<DashboardStart>(_onStart);
    on<DashboardStop>(_onStop);
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
        final now = DateTime.now();
        final all = snap.docs;
        final total = all.length;
        final upcoming = all.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final start = data['start'];
          if (start == null) return false;
          final startDt = (start as Timestamp).toDate();
          return startDt.isAfter(now);
        }).length;
        // For patients count we listen separately below and combine when available.
        // Emit partial if users subscription not ready
        add(_InternalUpdate(total, upcoming));
      });

      // Listen patients (usuarios role == Paciente) total
      _usersSub = _firestore.collection('usuarios').snapshots().listen((snap) {
        final patients = snap.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final role = (data['role'] ?? '').toString().toLowerCase();
          return role == 'paciente' || role == 'patient';
        }).length;
        add(_InternalPatientsUpdate(patients));
      });
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  // Internal events to combine streams without making public API complex
  void _onStop(DashboardStop event, Emitter<DashboardState> emit) {
    _citasSub?.cancel();
    _usersSub?.cancel();
  }

  // Small internal event handling via add(...) using private classes:
  void add(dynamic event) {
    if (event is _InternalUpdate) {
      final current = state is DashboardLoaded ? state as DashboardLoaded : DashboardLoaded(totalAppointments: 0, upcomingAppointments: 0, totalPatients: 0);
      emit(DashboardLoaded(
        totalAppointments: event.total,
        upcomingAppointments: event.upcoming,
        totalPatients: current.totalPatients,
      ));
    } else if (event is _InternalPatientsUpdate) {
      final current = state is DashboardLoaded ? state as DashboardLoaded : DashboardLoaded(totalAppointments: 0, upcomingAppointments: 0, totalPatients: 0);
      emit(DashboardLoaded(
        totalAppointments: current.totalAppointments,
        upcomingAppointments: current.upcomingAppointments,
        totalPatients: event.patients,
      ));
    } else {
      super.add(event);
    }
  }

  @override
  Future<void> close() {
    _citasSub?.cancel();
    _usersSub?.cancel();
    return super.close();
  }
}

// Private helper internal "events"
class _InternalUpdate {
  final int total;
  final int upcoming;
  _InternalUpdate(this.total, this.upcoming);
}
class _InternalPatientsUpdate {
  final int patients;
  _InternalPatientsUpdate(this.patients);
}