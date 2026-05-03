// TODO(release): remove demo accounts before public App Store launch.
//
// Wraps the real AuthRepository. If the email matches one of the four hard-coded
// demo accounts, we short-circuit the network call, write a fake user + token to
// secure storage (so the rest of the app sees us as authenticated), and return
// Right(demoUser) — the AuthBloc then emits AuthAuthenticated naturally.
// Any non-demo email passes through to the real repo unchanged.

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../models/user_model.dart';

class DemoAccount {
  final String label;
  final IconData icon;
  final Color color;
  final String email;
  final String password; // not validated; UI passes it for symmetry
  final UserModel user;

  const DemoAccount({
    required this.label,
    required this.icon,
    required this.color,
    required this.email,
    required this.password,
    required this.user,
  });
}

UserModel _user({
  required String id,
  required String email,
  required String firstName,
  required String lastName,
  required UserRole role,
}) {
  return UserModel(
    id: id,
    email: email,
    firstName: firstName,
    lastName: lastName,
    phoneNumber: null,
    profileImageUrl: null,
    createdAt: DateTime(2025, 1, 1),
    lastLoginAt: DateTime.now(),
    isEmailVerified: true,
    role: role,
  );
}

const String kDemoPassword = 'demo-pass-1234';

final List<DemoAccount> kDemoAccounts = [
  DemoAccount(
    label: 'Propriétaire',
    icon: Icons.workspace_premium,
    color: Colors.amber,
    email: 'owner.demo@wintime.test',
    password: kDemoPassword,
    user: _user(
      id: 'demo-owner-001',
      email: 'owner.demo@wintime.test',
      firstName: 'Olivia',
      lastName: 'Owner',
      role: UserRole.restaurantOwner,
    ),
  ),
  DemoAccount(
    label: 'Manager',
    icon: Icons.assignment_ind,
    color: Colors.indigo,
    email: 'manager.demo@wintime.test',
    password: kDemoPassword,
    user: _user(
      id: 'demo-manager-001',
      email: 'manager.demo@wintime.test',
      firstName: 'Marc',
      lastName: 'Manager',
      role: UserRole.restaurantManager,
    ),
  ),
  DemoAccount(
    label: 'Staff',
    icon: Icons.restaurant_menu,
    color: Colors.teal,
    email: 'staff.demo@wintime.test',
    password: kDemoPassword,
    user: _user(
      id: 'demo-staff-001',
      email: 'staff.demo@wintime.test',
      firstName: 'Sam',
      lastName: 'Staff',
      role: UserRole.restaurantStaff,
    ),
  ),
  DemoAccount(
    label: 'Admin',
    icon: Icons.admin_panel_settings,
    color: Colors.deepPurple,
    email: 'admin.demo@wintime.test',
    password: kDemoPassword,
    user: _user(
      id: 'demo-admin-001',
      email: 'admin.demo@wintime.test',
      firstName: 'Alex',
      lastName: 'Admin',
      role: UserRole.admin,
    ),
  ),
];

DemoAccount? _lookupDemo(String email) {
  final normalized = email.trim().toLowerCase();
  for (final acc in kDemoAccounts) {
    if (acc.email.toLowerCase() == normalized) return acc;
  }
  return null;
}

bool isDemoEmail(String email) => _lookupDemo(email) != null;

class DemoAuthRepository implements AuthRepository {
  final AuthRepository _real;
  final AuthLocalDataSource _local;
  final DioClient _dioClient;

  DemoAuthRepository({
    required AuthRepository real,
    required AuthLocalDataSource local,
    required DioClient dioClient,
  })  : _real = real,
        _local = local,
        _dioClient = dioClient;

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    final demo = _lookupDemo(email);
    if (demo == null) {
      return _real.login(email: email, password: password);
    }
    // Demo path — bypass network entirely.
    final fakeAccess = 'demo-token-${demo.user.role.name}';
    final fakeRefresh = 'demo-refresh-${demo.user.role.name}';
    await _local.saveTokens(
      accessToken: fakeAccess,
      refreshToken: fakeRefresh,
    );
    await _local.saveUser(demo.user);
    _dioClient.setAuthToken(fakeAccess);
    return Right(demo.user);
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required Map<String, dynamic> restaurantData,
  }) =>
      _real.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        restaurantData: restaurantData,
      );

  @override
  Future<Either<Failure, void>> logout() => _real.logout();

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() => _real.getCurrentUser();

  @override
  Future<Either<Failure, void>> forgotPassword({required String email}) =>
      _real.forgotPassword(email: email);

  @override
  Future<Either<Failure, void>> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _real.resetPassword(token: token, newPassword: newPassword);

  @override
  Future<Either<Failure, void>> verifyEmail({required String token}) =>
      _real.verifyEmail(token: token);

  @override
  Future<Either<Failure, bool>> isAuthenticated() => _real.isAuthenticated();

  @override
  Future<Either<Failure, String>> refreshToken() => _real.refreshToken();
}
