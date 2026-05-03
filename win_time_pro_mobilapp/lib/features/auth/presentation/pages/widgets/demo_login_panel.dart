// TODO(release): remove demo accounts before public App Store launch.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/demo_auth_repository.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';

class DemoLoginPanel extends StatelessWidget {
  const DemoLoginPanel({super.key});

  void _pick(BuildContext context, DemoAccount account) {
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            email: account.email,
            password: account.password,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (a, b) =>
          (a is AuthLoading) != (b is AuthLoading),
      builder: (context, state) {
        final busy = state is AuthLoading;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.08),
            border: Border.all(color: Colors.amber, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.science_outlined, size: 18, color: Colors.brown),
                  SizedBox(width: 6),
                  Text(
                    'TEST — Connexion rapide par rôle',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Choisis un rôle pour entrer dans l\'app sans mot de passe',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final account in kDemoAccounts)
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _pick(context, account),
                      icon: Icon(account.icon, color: account.color),
                      label: Text(account.label),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: account.color,
                        side: BorderSide(color: account.color),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
