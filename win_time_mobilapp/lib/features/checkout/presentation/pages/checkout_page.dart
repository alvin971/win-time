import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../cart/presentation/bloc/cart_bloc.dart';
import '../../../orders/data/datasources/supabase_orders_datasource.dart';
import '../../data/stripe_payment_service.dart';

/// Page checkout : récap panier + form customer info + bouton "Passer commande"
/// qui INSERT dans wintime.orders.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instructionsController = TextEditingController();
  bool _submitting = false;

  /// User-selected pickup time. Defaults to "ASAP" (+30 min). The picker
  /// rounds to 15-min slots and refuses anything earlier than now+15min.
  DateTime _pickupAt = DateTime.now().add(const Duration(minutes: 30));

  late final SupabaseOrdersDataSource _ordersDs;

  @override
  void initState() {
    super.initState();
    _ordersDs = SupabaseOrdersDataSource(Supabase.instance.client);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _nameController.text =
          (user.userMetadata?['first_name']?.toString() ?? '') +
              (user.userMetadata?['last_name'] != null
                  ? ' ${user.userMetadata!['last_name']}'
                  : '');
      _nameController.text = _nameController.text.trim();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  /// Submits the order to wintime.orders. The server-side trigger
  /// (`recompute_and_validate_order_amounts` from migration 050) re-derives
  /// subtotal/tax/total in cents from `wintime.products` and **rejects** any
  /// client-supplied amount that diverges by more than 1 cent. We therefore
  /// only need to send the items (productId + quantity) — amounts shown to
  /// the user are an *estimate* until the server confirms.
  ///
  /// After the order is inserted, we either route to the Stripe payment
  /// flow (`StripePaymentService.pay`) or fall back to cash-on-pickup with
  /// `payment_status = pending` and a "pay at pickup" tracking screen.
  Future<void> _submit(CartState cart) async {
    if (!_formKey.currentState!.validate()) return;
    if (cart.isEmpty || cart.restaurantId == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non connecté.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final now = DateTime.now();
      final items = cart.lines
          .map((l) => OrderItemEntity(
                id: '${l.product.id}-${now.microsecondsSinceEpoch}',
                productId: l.product.id,
                productName: l.product.name,
                productImageUrl: l.product.mainImageUrl,
                quantity: l.quantity,
                unitPrice: l.product.price,
                totalPrice: l.lineTotal,
                selectedOptions: const [],
                modifications: const [],
              ))
          .toList();

      // Client-side ESTIMATE — the server overwrites with the canonical
      // amounts at insert time. Default 5.5% take-away rate per CGI 279 m
      // bis (the trigger may apply 10% / 20% per product).
      const estimatedRate = 0.055;
      final estSubtotal = cart.subtotal;
      final estTax = estSubtotal * estimatedRate;
      final estTotal = estSubtotal + estTax;

      final stripeAvailable = StripePaymentService.isAvailable;

      final order = OrderEntity(
        id: '',
        // orderNumber is filled by the server trigger
        // `wintime.fill_order_number` if empty.
        orderNumber: '',
        restaurantId: cart.restaurantId!,
        customerId: user.id,
        customerInfo: CustomerInfo(
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          email: user.email,
        ),
        items: items,
        subtotal: estSubtotal,
        taxAmount: estTax,
        totalAmount: estTotal,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        paymentMethod: stripeAvailable
            ? PaymentMethod.creditCard
            : PaymentMethod.cash,
        createdAt: now,
        scheduledPickupTime: _pickupAt,
        estimatedPreparationTime: 25,
        specialInstructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        updatedAt: now,
      );

      final orderId = await _ordersDs.createOrder(order);

      // If Stripe is configured, present the PaymentSheet. The webhook flips
      // payment_status server-side; we just need a successful local result.
      if (stripeAvailable) {
        bool paid = false;
        try {
          paid = await StripePaymentService.pay(
            orderId: orderId,
            merchantName: 'Win Time',
          );
        } on Exception catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Paiement échoué : $e')),
            );
          }
        }
        if (!mounted) return;
        if (!paid) {
          // Cancelled — leave the order as pending; user can retry from the
          // tracking page (NOT implemented yet — Sprint 2 TODO).
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Paiement annulé. Ta commande est en attente.',
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      context.read<CartBloc>().add(const CartCleared());
      // Replace so the user cannot navigate back to checkout.
      context.go('/orders/$orderId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur création commande : $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Bottom-sheet picker: now+15min to now+8h, 15-min slots, capped to
  /// restaurant business hours (not enforced client-side yet — the server
  /// can refuse via a future trigger).
  Future<void> _showPickupTimePicker() async {
    final now = DateTime.now();
    final earliest = now.add(const Duration(minutes: 15));
    final slots = <DateTime>[];
    var t = DateTime(earliest.year, earliest.month, earliest.day, earliest.hour,
        (earliest.minute / 15).ceil() * 15);
    final end = now.add(const Duration(hours: 8));
    while (t.isBefore(end)) {
      slots.add(t);
      t = t.add(const Duration(minutes: 15));
    }

    final fmt = DateFormat('EEEE d MMMM, HH:mm', 'fr_FR');
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Heure de retrait',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: slots.length,
                    itemBuilder: (ctx, i) {
                      final s = slots[i];
                      final isSelected =
                          s.difference(_pickupAt).inMinutes.abs() < 8;
                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.access_time,
                          color: isSelected ? Colors.orange : null,
                        ),
                        title: Text(fmt.format(s)),
                        subtitle: i == 0 ? const Text('Au plus tôt') : null,
                        onTap: () => Navigator.pop(ctx, s),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected != null) {
      setState(() => _pickupAt = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation de commande'),
        leading: const BackButton(),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, cart) {
          if (cart.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Ton panier est vide.'),
                  ],
                ),
              ),
            );
          }

          // Display-only estimate. Server trigger reapplies per-product VAT
          // (5.5% / 10% / 20%) and may adjust ±1 cent.
          final tax = cart.subtotal * 0.055;
          final total = cart.subtotal + tax;
          final pickupFmt = DateFormat('EEEE d MMM, HH:mm', 'fr_FR');

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Récapitulatif',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        for (final l in cart.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('${l.quantity}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(l.product.name)),
                                Text(
                                  '${l.lineTotal.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                        _Line(label: 'Sous-total', amount: cart.subtotal),
                        _Line(label: 'TVA (estimée)', amount: tax),
                        const SizedBox(height: 4),
                        _Line(label: 'Total', amount: total, bold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tes coordonnées',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => v == null || v.trim().length < 8
                      ? 'Numéro requis'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (optionnel)',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Heure de retrait'),
                    subtitle: Text(pickupFmt.format(_pickupAt)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showPickupTimePicker,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : () => _submit(cart),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          StripePaymentService.isAvailable
                              ? 'Payer ${total.toStringAsFixed(2)} €'
                              : 'Commander — ${total.toStringAsFixed(2)} €',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    StripePaymentService.isAvailable
                        ? 'Paiement sécurisé via Stripe'
                        : 'Paiement au retrait',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
                if (kDebugMode && !StripePaymentService.isAvailable) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '(STRIPE_PUBLISHABLE_KEY non défini — fallback cash)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  const _Line({required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${amount.toStringAsFixed(2)} €', style: style),
        ],
      ),
    );
  }
}
