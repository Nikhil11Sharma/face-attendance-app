import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthBloc() : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthLoginRequested>(_onLogin);
    on<AuthSignUpRequested>(_onSignUp);
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
      emit(const AuthError(message: 'Sign in failed. Try again.'));
    }
  }

  Future<void> _onSignUp(AuthSignUpRequested e, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: e.email,
        password: e.password,
      );
      emit(AuthAuthenticated(
          uid: cred.user!.uid, email: cred.user!.email ?? ''));
    } on FirebaseAuthException catch (ex) {
      emit(AuthError(message: _signUpMsg(ex.code)));
    } catch (_) {
      emit(const AuthError(message: 'Sign up failed. Try again.'));
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
      case 'user-not-found':     return 'No account found with this email. Please sign up first.';
      case 'wrong-password':     return 'Incorrect password. Try again.';
      case 'invalid-credential': return 'Invalid email or password. Please check and try again.';
      case 'invalid-email':      return 'Invalid email address format.';
      case 'user-disabled':      return 'Account disabled. Contact admin.';
      case 'too-many-requests':  return 'Too many attempts. Wait a moment and try again.';
      default:                   return 'Sign in failed. Please try again.';
    }
  }

  String _signUpMsg(String code) {
    switch (code) {
      case 'email-already-in-use': return 'This email already has an account. Please sign in.';
      case 'weak-password':         return 'Password too weak. Use at least 6 characters.';
      case 'invalid-email':         return 'Invalid email address format.';
      default:                      return 'Sign up failed. Please try again.';
    }
  }
}
