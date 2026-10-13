import 'package:equatable/equatable.dart';
import '../../../../domain/entities/entities.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Teacher teacher;
  const AuthAuthenticated({required this.teacher});

  @override
  List<Object?> get props => [teacher.id];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
