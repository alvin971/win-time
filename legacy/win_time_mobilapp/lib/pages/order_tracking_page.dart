import 'dart:async';
import 'package:flutter/material.dart';
import '../models/restaurant_models.dart';

class OrderTrackingPage extends StatefulWidget {
  final Order order;

  const OrderTrackingPage({super.key, required this.order});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  late String currentStatus;
  Timer? _timer;
  int _elapsedSeconds = 0;

  final List<Map<String, dynamic>> orderSteps = [
    {
      'status': 'Confirmée',
      'icon': Icons.check_circle,
      'description': 'Votre commande a été confirmée',
    },
    {
      'status': 'En préparation',
      'icon': Icons.restaurant_menu,
      'description': 'Le restaurant prépare votre commande',
    },
    {
      'status': 'Prête',
      'icon': Icons.done_all,
      'description': 'Votre commande est prête',
    },
    {
      'status': 'En livraison',
      'icon': Icons.delivery_dining,
      'description': 'Votre commande est en route',
    },
    {
      'status': 'Livrée',
      'icon': Icons.home,
      'description': 'Commande livrée - Bon appétit !',
    },
  ];

  @override
  void initState() {
    super.initState();
    currentStatus = widget.order.status;

    // Simuler la progression de la commande
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _elapsedSeconds += 5;

        // Progression automatique des statuts
        if (_elapsedSeconds == 5) {
          currentStatus = 'Confirmée';
        } else if (_elapsedSeconds == 10) {
          currentStatus = 'En préparation';
        } else if (_elapsedSeconds == 30) {
          currentStatus = 'Prête';
        } else if (_elapsedSeconds == 40) {
          currentStatus = 'En livraison';
        } else if (_elapsedSeconds == 60) {
          currentStatus = 'Livrée';
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get currentStepIndex {
    return orderSteps.indexWhere((step) => step['status'] == currentStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de commande'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête avec info commande
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.order.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.order.restaurantName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total payé',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${widget.order.total.toStringAsFixed(2)}€',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Statut actuel en grand
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  orderSteps[currentStepIndex]['icon'] as IconData,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  currentStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  orderSteps[currentStepIndex]['description'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Timeline des étapes
          const Text(
            'Progression de la commande',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          ...List.generate(orderSteps.length, (index) {
            final step = orderSteps[index];
            final isCompleted = index <= currentStepIndex;
            final isCurrent = index == currentStepIndex;

            return _buildTimelineStep(
              icon: step['icon'] as IconData,
              status: step['status'] as String,
              description: step['description'] as String,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isLast: index == orderSteps.length - 1,
            );
          }),

          const SizedBox(height: 24),

          // Détails de la commande
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Articles commandés',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...widget.order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(item.menuItem.name),
                            ),
                            Text(
                              '${item.totalPrice.toStringAsFixed(2)}€',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Boutons d'action
          if (currentStatus != 'Livrée')
            OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Contacter le restaurant'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.phone),
                          title: const Text('Appeler'),
                          onTap: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Appel en cours...'),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.message),
                          title: const Text('Envoyer un message'),
                          onTap: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Messagerie ouverte'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.phone),
              label: const Text('Contacter le restaurant'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String status,
    required String description,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isCompleted ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    fontSize: isCurrent ? 16 : 14,
                    color: isCompleted ? Colors.black : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
