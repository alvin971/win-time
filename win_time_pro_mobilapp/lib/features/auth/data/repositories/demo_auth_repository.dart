// Helpers UI pour le panel démo de la LoginPage.
//
// Avant migration Supabase, ce fichier wrappait AuthRepository pour
// court-circuiter le réseau et écrire des fake tokens en local — utile quand
// le backend HTTP n'existait pas encore. Maintenant que les 4 comptes démo
// sont vraiment seedés dans Supabase Auth (cf. scripts/seed_supabase.js),
// le wrapper n'est plus nécessaire : le DemoLoginPanel appelle directement
// `AuthRepository.login(email, password)` avec les credentials hardcodés
// ci-dessous, et Supabase fait tout le travail.
//
// Le fichier est conservé uniquement pour exposer la liste [kDemoAccounts]
// aux widgets UI (icône, couleur, label). En kReleaseMode, le DemoLoginPanel
// ne s'affichera pas (cf. login_page.dart).

import 'package:flutter/material.dart';

import '../../domain/entities/user_entity.dart' show UserRole;

class DemoAccount {
  final String label;
  final IconData icon;
  final Color color;
  final String email;
  final String password;
  final UserRole role;

  /// Sous-titre indiquant si ce compte est lié à un resto seedé.
  /// Sert à éviter la confusion : seul "Propriétaire" possède La Trattoria.
  /// Les autres rôles n'ont rien et tombent sur l'empty state.
  final String hint;

  const DemoAccount({
    required this.label,
    required this.icon,
    required this.color,
    required this.email,
    required this.password,
    required this.role,
    required this.hint,
  });
}

const String kDemoPassword = 'demo-pass-1234';

const List<DemoAccount> kDemoAccounts = [
  DemoAccount(
    label: 'Propriétaire',
    icon: Icons.workspace_premium,
    color: Colors.amber,
    email: 'owner.demo@wintime.test',
    password: kDemoPassword,
    role: UserRole.restaurantOwner,
    hint: '🇮🇹 La Trattoria',
  ),
  DemoAccount(
    label: 'Manager',
    icon: Icons.assignment_ind,
    color: Colors.indigo,
    email: 'manager.demo@wintime.test',
    password: kDemoPassword,
    role: UserRole.restaurantOwner,
    hint: '🇫🇷 Bistrot du Louvre',
  ),
  DemoAccount(
    label: 'Staff',
    icon: Icons.restaurant_menu,
    color: Colors.teal,
    email: 'staff.demo@wintime.test',
    password: kDemoPassword,
    role: UserRole.restaurantOwner,
    hint: '🇯🇵 Sakura Sushi',
  ),
  DemoAccount(
    label: 'Admin',
    icon: Icons.admin_panel_settings,
    color: Colors.deepPurple,
    email: 'admin.demo@wintime.test',
    password: kDemoPassword,
    role: UserRole.restaurantOwner,
    hint: '🇱🇧 Beirut Étoile',
  ),
];
