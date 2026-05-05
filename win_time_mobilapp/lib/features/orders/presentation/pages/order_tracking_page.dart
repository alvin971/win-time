import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/supabase_orders_datasource.dart';

/// Page tracking d'une commande spécifique. Stream realtime — quand le
/// restaurant change le statut, l'UI se met à jour instantanément.
class OrderTrackingPage extends StatefulWidget {
  final String orderId;
  const OrderTrackingPage({super.key, required this.orderId});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  late final SupabaseOrdersDataSource _ds;
  late final Stream<OrderEntity?> _stream;

  @override
  void initState() {
    super.initState();
    _ds = SupabaseOrdersDataSource(Supabase.instance.client);
    _stream = _ds.watchOrderById(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de commande'),
        leading: BackButton(
          onPressed: () {
            // Si la stack a un parent (ex: cart→checkout→tracking), pop normalement.
            // Sinon (deep link), aller à /home/orders.
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/home/orders');
            }
          },
        ),
      ),
      body: StreamBuilder<OrderEntity?>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          final order = snap.data;
          if (order == null) {
            return const Center(child: Text('Commande introuvable.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(order: order),
              const SizedBox(height: 16),
              _OrderActions(order: order, dataSource: _ds),
              const SizedBox(height: 16),
              Text('Avancement',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 12),
              _StatusTimeline(order: order),
              const SizedBox(height: 24),
              Text('Récapitulatif',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text('${item.quantity}× ',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(item.productName)),
                              Text(item.formattedTotalPrice),
                            ],
                          ),
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(order.formattedTotal,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (order.specialInstructions != null) ...[
                const SizedBox(height: 16),
                Text('Instructions',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 4),
                Text(order.specialInstructions!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final OrderEntity order;
  const _Header({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Commande ${order.orderNumber}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            Text(
                'Passée le ${order.createdAt.day}/${order.createdAt.month} '
                'à ${order.createdAt.hour.toString().padLeft(2, '0')}:'
                '${order.createdAt.minute.toString().padLeft(2, '0')}'),
            const SizedBox(height: 4),
            if (order.scheduledPickupTime != null)
              Text(
                'Retrait prévu : '
                '${order.scheduledPickupTime!.hour.toString().padLeft(2, '0')}:'
                '${order.scheduledPickupTime!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final OrderEntity order;
  const _StatusTimeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = <_Step>[
      _Step(
        label: 'Commande reçue',
        time: order.createdAt,
        active: true,
        icon: Icons.receipt,
      ),
      _Step(
        label: 'Acceptée',
        time: order.acceptedAt,
        active: order.acceptedAt != null ||
            order.status == OrderStatus.accepted ||
            order.status == OrderStatus.preparing ||
            order.status == OrderStatus.ready ||
            order.status == OrderStatus.completed,
        icon: Icons.thumb_up,
      ),
      _Step(
        label: 'Prête à retirer',
        time: order.readyAt,
        active: order.readyAt != null ||
            order.status == OrderStatus.ready ||
            order.status == OrderStatus.completed,
        icon: Icons.check_circle,
      ),
      _Step(
        label: 'Retirée',
        time: order.completedAt,
        active: order.completedAt != null ||
            order.status == OrderStatus.completed,
        icon: Icons.delivery_dining,
      ),
    ];
    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.rejected) {
      steps.add(_Step(
        label: order.status == OrderStatus.cancelled ? 'Annulée' : 'Refusée',
        time: order.cancelledAt,
        active: true,
        icon: Icons.cancel,
        color: Colors.red,
      ));
    }

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: steps[i].active
                          ? (steps[i].color ?? Colors.green)
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(steps[i].icon, size: 16, color: Colors.white),
                  ),
                  if (i < steps.length - 1)
                    Container(
                      width: 2,
                      height: 30,
                      color: steps[i + 1].active
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].label,
                        style: TextStyle(
                          fontWeight: steps[i].active
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: steps[i].active
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                      if (steps[i].time != null)
                        Text(
                          '${steps[i].time!.hour.toString().padLeft(2, '0')}:'
                          '${steps[i].time!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Step {
  final String label;
  final DateTime? time;
  final bool active;
  final IconData icon;
  final Color? color;
  _Step({
    required this.label,
    this.time,
    required this.active,
    required this.icon,
    this.color,
  });
}

/// Actions contextuelles selon le statut :
/// - pending → bouton "Annuler ma commande"
/// - completed (et !isRated) → CTA "Donner une note"
/// - autres → rien
class _OrderActions extends StatefulWidget {
  final OrderEntity order;
  final SupabaseOrdersDataSource dataSource;
  const _OrderActions({required this.order, required this.dataSource});

  @override
  State<_OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends State<_OrderActions> {
  bool _busy = false;

  Future<void> _cancelOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ma commande ?'),
        content: const Text(
            'Cette action est irréversible. Tu pourras repasser commande à tout moment.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Garder')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Annuler la commande'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.dataSource.cancelOrder(
        orderId: widget.order.id,
        reason: 'Annulée par le client',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande annulée')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRatingSheet() async {
    int rating = 5;
    final reviewCtrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Note ton expérience',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      iconSize: 36,
                      icon: Icon(
                        i <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () => setSheet(() => rating = i),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reviewCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Commentaire (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx2, true),
                icon: const Icon(Icons.send),
                label: const Text('Envoyer'),
              ),
            ],
          ),
        ),
      ),
    );
    reviewCtrl.dispose();
    if (result != true) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client
          .schema('wintime')
          .from('orders')
          .update({
            'rating': rating,
            'review': reviewCtrl.text.trim().isEmpty ? null : reviewCtrl.text.trim(),
            'is_rated': true,
          })
          .eq('id', widget.order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci pour ton avis !')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    if (order.status == OrderStatus.pending) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : _cancelOrder,
        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
        label: const Text('Annuler ma commande',
            style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }
    if (order.status == OrderStatus.completed && !order.isRated) {
      return ElevatedButton.icon(
        onPressed: _busy ? null : _showRatingSheet,
        icon: const Icon(Icons.star_outline),
        label: const Text('Donner une note'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }
    if (order.isRated && order.rating != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text('Tu as noté ${order.rating!.toStringAsFixed(1)} / 5',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
