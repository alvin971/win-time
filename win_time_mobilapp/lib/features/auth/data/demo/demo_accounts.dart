// TODO(release): remove demo accounts before public App Store launch.
//
// Quick "tap-a-role" buttons displayed on LoginPage so testers can
// authenticate as any user role without backend credentials.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/user_entity.dart';
import '../datasources/auth_local_datasource.dart';
import '../models/user_model.dart';

class DemoAccount {
  final String label;
  final IconData icon;
  final Color color;
  final UserModel user;

  const DemoAccount({
    required this.label,
    required this.icon,
    required this.color,
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
    role: role,
    isActive: true,
    isVerified: true,
    createdAt: DateTime(2025, 1, 1),
    lastLogin: DateTime.now(),
  );
}

final List<DemoAccount> kDemoAccounts = [
  DemoAccount(
    label: 'Client',
    icon: Icons.person,
    color: Colors.blue,
    user: _user(
      id: 'demo-client-001',
      email: 'client.demo@wintime.test',
      firstName: 'Camille',
      lastName: 'Client',
      role: UserRole.client,
    ),
  ),
  DemoAccount(
    label: 'Restaurateur',
    icon: Icons.restaurant,
    color: Colors.orange,
    user: _user(
      id: 'demo-resto-001',
      email: 'resto.demo@wintime.test',
      firstName: 'Renée',
      lastName: 'Restaurateur',
      role: UserRole.restaurant,
    ),
  ),
  DemoAccount(
    label: 'Admin',
    icon: Icons.admin_panel_settings,
    color: Colors.deepPurple,
    user: _user(
      id: 'demo-admin-001',
      email: 'admin.demo@wintime.test',
      firstName: 'Alex',
      lastName: 'Admin',
      role: UserRole.admin,
    ),
  ),
];

Future<void> loginAsDemo(DemoAccount account) async {
  final local = AuthLocalDataSourceImpl(const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ));
  await local.saveTokens(
    accessToken: 'demo-token-${account.user.role.name}',
    refreshToken: 'demo-refresh-${account.user.role.name}',
  );
  await local.saveUser(account.user);
}
