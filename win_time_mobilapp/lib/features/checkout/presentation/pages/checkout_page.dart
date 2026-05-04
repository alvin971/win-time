import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../cart/presentation/bloc/cart_bloc.dart';
import '../../../orders/data/datasources/supabase_orders_datasource.dart';

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
      final orderNumber =
          'WT-${now.millisecondsSinceEpoch.toString().substring(7)}';
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
      final taxRate = 0.10; // 10% de TVA mock
      final subtotal = cart.subtotal;
      final taxAmount = (subtotal * taxRate);
      final total = subtotal + taxAmount;

      final order = OrderEntity(
        id: '',
        orderNumber: orderNumber,
        restaurantId: cart.restaurantId!,
        customerId: user.id,
        customerInfo: CustomerInfo(
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          email: user.email,
        ),
        items: items,
        subtotal: subtotal,
        taxAmount: taxAmount,
        totalAmount: total,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        paymentMethod: PaymentMethod.cash,
        createdAt: now,
        scheduledPickupTime: now.add(const Duration(minutes: 30)),
        estimatedPreparationTime: 25,
        specialInstructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        updatedAt: now,
      );

      final orderId = await _ordersDs.createOrder(order);
      if (!mounted) return;
      context.read<CartBloc>().add(const CartCleared());
      // Replace pour ne pas pouvoir revenir au checkout après confirmation
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validation de commande')),
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

          final tax = cart.subtotal * 0.10;
          final total = cart.subtotal + tax;

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
                        _Line(label: 'TVA (10%)', amount: tax),
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
                          'Passer commande — ${total.toStringAsFixed(2)} €',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Paiement à la livraison (mock)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
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
