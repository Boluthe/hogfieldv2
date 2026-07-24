import 'package:equatable/equatable.dart';
import '../../domain/entities/role.dart';

class AuthState extends Equatable {
  final UserRole role;
  final String error;

  const AuthState({
    this.role = UserRole.none,
    this.error = '',
  });

  AuthState copyWith({
    UserRole? role,
    String? error,
  }) {
    return AuthState(
      role: role ?? this.role,
      error: error ?? this.error,
    );
  }

  @override
  List<Object> get props => [role, error];
}
