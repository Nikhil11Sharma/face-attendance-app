import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import 'auth_event.dart';
import 'auth_state.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../services/audit/audit_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AuditService _auditService;
  final Logger _log = Logger();

  AuthBloc({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required AuditService auditService,
  })  : _auth = auth,
        _firestore = firestore,
        _auditService = auditService,
        super(AuthInitial()) {
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthPasswordResetRequested>(_onPasswordReset);
    on<AuthCheckRequested>(_onCheckAuth);

    // Listen to Firebase auth state changes
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        add(AuthCheckRequested());
      }
    });
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      final teacher = await _fetchTeacherProfile(credential.user!.uid);
      if (teacher == null) {
        emit(const AuthError(
          message: 'Teacher account not found. Contact admin.',
        ));
        await _auth.signOut();
        return;
      }

      _auditService.setActor(teacher.id, teacher.role.name);
      await _auditService.log(
        action: AuditActions.loginSuccess,
        targetType: 'teacher',
        targetId: teacher.id,
      );

      emit(AuthAuthenticated(teacher: teacher));
    } on FirebaseAuthException catch (e) {
      await _auditService.log(
        action: AuditActions.loginFailure,
        targetType: 'teacher',
        targetId: event.email,
        reason: e.code,
      );
      emit(AuthError(message: _authErrorMessage(e.code)));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onCheckAuth(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      emit(AuthUnauthenticated());
      return;
    }

    try {
      final teacher = await _fetchTeacherProfile(user.uid);
      if (teacher != null) {
        _auditService.setActor(teacher.id, teacher.role.name);
        emit(AuthAuthenticated(teacher: teacher));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _auth.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onPasswordReset(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _auth.sendPasswordResetEmail(email: event.email);
    } catch (e) {
      _log.e('Password reset failed: $e');
    }
  }

  Future<Teacher?> _fetchTeacherProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.colTeachers)
          .doc(uid)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return Teacher(
        id: uid,
        name: data['name'] as String? ?? '',
        email: data['email'] as String? ?? '',
        employeeId: data['employeeId'] as String? ?? '',
        collegeId: data['collegeId'] as String? ?? '',
        role: TeacherRole.values.firstWhere(
          (r) => r.name == (data['role'] as String? ?? 'teacher'),
          orElse: () => TeacherRole.teacher,
        ),
        classIds: List<String>.from(data['classIds'] as List? ?? []),
        isActive: data['isActive'] as bool? ?? true,
      );
    } catch (e) {
      _log.e('Failed to fetch teacher profile: $e');
      return null;
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'Account has been disabled. Contact admin.';
      case 'too-many-requests':
        return 'Too many failed attempts. Try again later.';
      default:
        return 'Login failed. Please try again.';
    }
  }
}
