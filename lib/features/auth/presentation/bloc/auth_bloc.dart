import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/data/hive_database.dart';
import '../../domain/entities/role.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const String _cashierPinKey = 'cashier_pin';
  static const String _staffPinKey = 'staff_pin';
  static const String _defaultCashierPin = '1111';
  static const String _defaultStaffPin = '2222';

  AuthBloc() : super(const AuthState()) {
    on<CheckAuthEvent>(_onCheckAuth);
    on<LoginWithPinEvent>(_onLoginWithPin);
    on<LogoutEvent>(_onLogout);
    on<ChangePinEvent>(_onChangePin);
  }

  void _onCheckAuth(CheckAuthEvent event, Emitter<AuthState> emit) {
    // For this flow, we always start logged out (requiring PIN)
    emit(const AuthState(role: UserRole.none));
  }

  void _onLoginWithPin(LoginWithPinEvent event, Emitter<AuthState> emit) {
    // Clear any previous error to ensure a state change occurs
    emit(state.copyWith(error: ''));

    final settingsBox = HiveDatabase.settingsBox;
    final cashierPin = settingsBox.get(_cashierPinKey, defaultValue: _defaultCashierPin);
    final staffPin = settingsBox.get(_staffPinKey, defaultValue: _defaultStaffPin);

    if (event.pin == cashierPin) {
      emit(const AuthState(role: UserRole.cashier, error: ''));
    } else if (event.pin == staffPin) {
      emit(const AuthState(role: UserRole.staff, error: ''));
    } else {
      emit(state.copyWith(error: 'Invalid PIN: ${event.pin}'));
    }
  }

  void _onLogout(LogoutEvent event, Emitter<AuthState> emit) {
    emit(const AuthState(role: UserRole.none, error: ''));
  }

  void _onChangePin(ChangePinEvent event, Emitter<AuthState> emit) {
    final settingsBox = HiveDatabase.settingsBox;
    if (event.role == 'cashier') {
      settingsBox.put(_cashierPinKey, event.newPin);
    } else {
      settingsBox.put(_staffPinKey, event.newPin);
    }
    // PIN changed successfully
  }
}
