import 'package:flutter/material.dart';
import '../models/restaurant_models.dart';
import 'order_confirmation_page.dart';

class CheckoutPage extends StatefulWidget {
  final Restaurant restaurant;
  final List<CartItem> cartItems;
  final double subtotal;
  final double winTimeFee;
  final double total;

  const CheckoutPage({
    super.key,
    required this.restaurant,
    required this.cartItems,
    required this.subtotal,
    required this.winTimeFee,
    required this.total,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String _deliveryTime = 'asap';
  String? _selectedTimeSlot;
  bool _isProcessing = false;

  // Créneaux horaires disponibles pour Click & Collect
  final List<String> _timeSlots = _generateTimeSlots();

  static List<String> _generateTimeSlots() {
    final now = DateTime.now();
    final slots = <String>[];

    // Générer des créneaux de 30 minutes pour les 4 prochaines heures
    for (int i = 1; i <= 8; i++) {
      final time = now.add(Duration(minutes: 30 * i));
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      slots.add('$hour:$minute');
    }

    return slots;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    // Simuler le traitement de la commande
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Créer la commande
    final order = Order(
      id: 'ORD${DateTime.now().millisecondsSinceEpoch}',
      restaurantId: widget.restaurant.id,
      restaurantName: widget.restaurant.name,
      items: widget.cartItems,
      subtotal: widget.subtotal,
      winTimeFee: widget.winTimeFee,
      total: widget.total,
      status: 'En préparation',
      orderTime: DateTime.now(),
      estimatedTime: _deliveryTime == 'asap'
          ? widget.restaurant.prepTime
          : (_selectedTimeSlot ?? 'Créneau programmé'),
    );

    setState(() {
      _isProcessing = false;
    });

    // Navigation vers la page de confirmation
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => OrderConfirmationPage(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finaliser la commande'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Section Livraison
                _buildSection(
                  title: 'Informations de livraison',
                  icon: Icons.location_on,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre numéro';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse de livraison',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre adresse';
                        }
                        return null;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Section Click & Collect - Créneaux horaires
                _buildSection(
                  title: 'Créneau de retrait (Click & Collect)',
                  icon: Icons.schedule,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Choisissez votre créneau horaire pour récupérer votre commande',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<String>(
                      title: const Text('Dès que possible'),
                      subtitle: Text('Prêt dans ${widget.restaurant.prepTime}'),
                      value: 'asap',
                      groupValue: _deliveryTime,
                      onChanged: (value) {
                        setState(() {
                          _deliveryTime = value!;
                          _selectedTimeSlot = null;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Choisir un créneau'),
                      subtitle: _selectedTimeSlot != null
                          ? Text('Retrait à $_selectedTimeSlot')
                          : const Text('Sélectionnez une heure'),
                      value: 'scheduled',
                      groupValue: _deliveryTime,
                      onChanged: (value) {
                        setState(() {
                          _deliveryTime = value!;
                        });
                      },
                    ),
                    if (_deliveryTime == 'scheduled')
                      Container(
                        margin: const EdgeInsets.only(left: 16, top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _timeSlots.map((slot) {
                            final isSelected = _selectedTimeSlot == slot;
                            return ChoiceChip(
                              label: Text(slot),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTimeSlot = slot;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // Info paiement sur place
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Paiement sur place',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vous réglerez directement au restaurant lors du retrait',
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Section Notes
                _buildSection(
                  title: 'Instructions spéciales',
                  icon: Icons.note,
                  children: [
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Sans oignons, sonnez 2 fois, etc.',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Résumé de la commande
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Résumé de la commande',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Divider(height: 24),
                        // Liste détaillée des articles
                        ...widget.cartItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantity}x ${item.menuItem.name}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                '${item.totalPrice.toStringAsFixed(2)}€',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        )),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Sous-total'),
                            Text('${widget.subtotal.toStringAsFixed(2)}€'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Frais Win Time (2%)'),
                            Text('${widget.winTimeFee.toStringAsFixed(2)}€'),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${widget.total.toStringAsFixed(2)}€',
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

                // Bouton Commander
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _placeOrder,
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Confirmer la commande',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Traitement de votre commande...',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}
