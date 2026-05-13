import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_model.dart';

/// Bottom sheet shown when the Pro user taps "Vérifier code" on a ready
/// order. Restaurateur types the 6-digit code the customer is showing them;
/// on match we flip the order to `completed` via the state-machine trigger.
class PickupCodeVerifySheet extends StatefulWidget {
  final OrderModel order;
  final String expectedCode;
  const PickupCodeVerifySheet({
    super.key,
    required this.order,
    required this.expectedCode,
  });

  static Future<bool?> show(
    BuildContext context, {
    required OrderModel order,
    required String expectedCode,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PickupCodeVerifySheet(
        order: order,
        expectedCode: expectedCode,
      ),
    );
  }

  @override
  State<PickupCodeVerifySheet> createState() => _PickupCodeVerifySheetState();
}

class _PickupCodeVerifySheetState extends State<PickupCodeVerifySheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAndComplete() async {
    final entered = _ctrl.text.trim();
    if (entered.length != 6) {
      setState(() => _error = 'Le code fait 6 chiffres.');
      return;
    }
    if (entered != widget.expectedCode) {
      setState(() => _error = 'Code incorrect.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ServiceLocator.ordersDataSource.completeOrder(
        orderId: widget.order.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Erreur serveur : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Vérifier le code de retrait',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Demande au client le code à 6 chiffres affiché dans son app.',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            autofocus: true,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                letterSpacing: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _error,
            ),
            onSubmitted: (_) => _verifyAndComplete(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : _verifyAndComplete,
            icon: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: const Text('Valider le retrait'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
