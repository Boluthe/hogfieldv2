import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../domain/entities/role.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const String _adminPinKey = 'admin_pin';
  static const String _cashierPinKey = 'cashier_pin';
  static const String _staffPinKey = 'staff_pin';
  static const String _defaultAdminPin = '1969';
  static const String _defaultCashierPin = '1234';
  static const String _defaultStaffPin = '0000';

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

  Future<void> _onLoginWithPin(LoginWithPinEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(error: ''));

    final settingsBox = HiveDatabase.settingsBox;
    final adminPin = settingsBox.get(_adminPinKey, defaultValue: _defaultAdminPin);
    final cashierPin = settingsBox.get(_cashierPinKey, defaultValue: _defaultCashierPin);
    final staffPin = settingsBox.get(_staffPinKey, defaultValue: _defaultStaffPin);

    if (event.pin == adminPin) {
      CloudSyncService.start();
      emit(const AuthState(role: UserRole.admin, error: ''));
    } else if (event.pin == cashierPin) {
      CloudSyncService.start();
      emit(const AuthState(role: UserRole.cashier, error: ''));
    } else if (event.pin == staffPin) {
      CloudSyncService.start();
      emit(const AuthState(role: UserRole.staff, error: ''));
    } else {
      emit(state.copyWith(error: 'Invalid PIN. Please try again.'));
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    CloudSyncService.stop();
    emit(const AuthState(role: UserRole.none, error: ''));
  }

  Future<void> _onChangePin(ChangePinEvent event, Emitter<AuthState> emit) async {
    final settingsBox = HiveDatabase.settingsBox;
    if (event.role == 'admin') {
      settingsBox.put(_adminPinKey, event.newPin);
    } else if (event.role == 'cashier') {
      settingsBox.put(_cashierPinKey, event.newPin);
    } else {
      settingsBox.put(_staffPinKey, event.newPin);
    }
    
    // Also push to firestore but don't block
    try {
      final docRef = FirebaseFirestore.instance.collection('settings').doc('shop');
      if (event.role == 'admin') {
        docRef.set({_adminPinKey: event.newPin}, SetOptions(merge: true));
      } else if (event.role == 'cashier') {
        docRef.set({_cashierPinKey: event.newPin}, SetOptions(merge: true));
      } else {
        docRef.set({_staffPinKey: event.newPin}, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}
