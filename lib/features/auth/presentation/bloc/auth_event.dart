import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class CheckAuthEvent extends AuthEvent {}

class LoginWithPinEvent extends AuthEvent {
  final String pin;
  const LoginWithPinEvent(this.pin);

  @override
  List<Object> get props => [pin];
}

class LogoutEvent extends AuthEvent {}

class ChangePinEvent extends AuthEvent {
  final String role; // 'cashier' or 'staff'
  final String newPin;

  const ChangePinEvent(this.role, this.newPin);

  @override
  List<Object> get props => [role, newPin];
}
