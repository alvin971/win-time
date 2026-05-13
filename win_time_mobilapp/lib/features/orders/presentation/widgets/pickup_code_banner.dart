import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Large pickup-code banner shown to the customer once an order reaches
/// status=ready. Shows the 6-digit code + QR for the restaurateur to scan.
///
/// QR payload is `wintime:pickup/<orderId>/<code>` — a URL scheme the Pro
/// app's scanner (when mobile_scanner is re-enabled) can parse to pre-fill
/// the verify sheet.
class PickupCodeBanner extends StatelessWidget {
  final String orderId;
  final String code;
  const PickupCodeBanner({
    super.key,
    required this.orderId,
    required this.code,
  });

  String get _qrData => 'wintime:pickup/$orderId/$code';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.10),
            theme.colorScheme.primary.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.30),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Ta commande est prête ! 🍔',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Montre ce code au comptoir',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final digit in code.split(''))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 36,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      digit,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 140,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier le code'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copié')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
