import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthBloc() : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthPasswordResetRequested>(_onReset);
  }

  Future<void> _onCheck(AuthCheckRequested e, Emitter<AuthState> emit) async {
    final user = _auth.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(uid: user.uid, email: user.email ?? ''));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested e, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: e.email,
        password: e.password,
      );
      emit(AuthAuthenticated(
          uid: cred.user!.uid, email: cred.user!.email ?? ''));
    } on FirebaseAuthException catch (ex) {
      emit(AuthError(message: _msg(ex.code)));
    } catch (_) {
      emit(const AuthError(message: 'Login failed. Try again.'));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested e, Emitter<AuthState> emit) async {
    await _auth.signOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onReset(
      AuthPasswordResetRequested e, Emitter<AuthState> emit) async {
    try {
      await _auth.sendPasswordResetEmail(email: e.email);
    } catch (_) {}
  }

  String _msg(String code) {
    switch (code) {
      case 'user-not-found':      return 'No account found with this email.';
      case 'wrong-password':      return 'Incorrect password.';
      case 'invalid-credential':  return 'Invalid email or password.';
      case 'invalid-email':       return 'Invalid email address.';
      case 'user-disabled':       return 'Account disabled. Contact admin.';
      case 'too-many-requests':   return 'Too many attempts. Try later.';
      default:                    return 'Login failed. Please try again.';
    }
  }
}
