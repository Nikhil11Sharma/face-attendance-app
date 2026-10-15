import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthPasswordResetRequested>(_onReset);
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  bool get _firebaseReady => !kIsWeb;

  Future<void> _onCheck(AuthCheckRequested event, Emitter<AuthState> emit) async {
    if (!_firebaseReady) {
      emit(AuthUnauthenticated());
      return;
    }
    final user = _auth.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(uid: user.uid, email: user.email ?? ''));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    if (!_firebaseReady) {
      emit(const AuthError(message: 'Firebase not available on web preview.'));
      return;
    }
    emit(AuthLoading());
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(
        uid: cred.user!.uid,
        email: cred.user!.email ?? '',
      ));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _msg(e.code)));
    } catch (e) {
      emit(const AuthError(message: 'Login failed. Try again.'));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    if (_firebaseReady) await _auth.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onReset(AuthPasswordResetRequested event, Emitter<AuthState> emit) async {
    if (!_firebaseReady) return;
    try {
      await _auth.sendPasswordResetEmail(email: event.email);
    } catch (_) {}
  }

  String _msg(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'invalid-email': return 'Invalid email address.';
      case 'user-disabled': return 'Account disabled. Contact admin.';
      case 'too-many-requests': return 'Too many attempts. Try later.';
      default: return 'Login failed. Please try again.';
    }
  }
}
