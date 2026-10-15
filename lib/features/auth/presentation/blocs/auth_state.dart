abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  final String uid;
  final String email;
  const AuthAuthenticated({required this.uid, required this.email});
}

class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});
}
