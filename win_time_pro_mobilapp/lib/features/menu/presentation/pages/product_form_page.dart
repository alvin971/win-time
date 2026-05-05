import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection_container.dart';

/// Form CRUD pour un produit.
///
/// Mode CREATE si [existingProductId] est null, EDIT sinon.
/// Champs : nom, description, prix, photo, allergens (chips multi-select),
/// labels, isAvailable, prep time. Sizes/options/nutritional skip pour MVP.
class ProductFormPage extends StatefulWidget {
  final String restaurantId;
  final String categoryId;
  final String? existingProductId;
  const ProductFormPage({
    super.key,
    required this.restaurantId,
    required this.categoryId,
    required this.existingProductId,
  });

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String? _photoUrl;
  bool _isAvailable = true;
  int _prepTime = 15;
  Set<Allergen> _allergens = {};
  Set<ProductLabel> _labels = {};

  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  ProductEntity? _existing;

  bool get _isEdit => widget.existingProductId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadExisting();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadExisting() async {
    try {
      final products =
          await ServiceLocator.menuDataSource.getProducts(widget.restaurantId);
      final p = products.firstWhere(
        (p) => p.id == widget.existingProductId,
        orElse: () => throw Exception('Produit introuvable'),
      );
      if (!mounted) return;
      setState(() {
        _existing = p;
        _nameCtrl.text = p.name;
        _descCtrl.text = p.description;
        _priceCtrl.text = p.price.toStringAsFixed(2);
        _photoUrl = p.mainImageUrl;
        _isAvailable = p.isAvailable;
        _prepTime = p.estimatedPreparationTime;
        _allergens = p.allergens.toSet();
        _labels = p.labels.toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chargement échoué : $e')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ─── Photo upload ───────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 800,
        minHeight: 800,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) throw Exception('Compression échouée');
      final ownerUid = Supabase.instance.client.auth.currentUser?.id;
      if (ownerUid == null) throw Exception('Non connecté');
      // En mode CREATE, on n'a pas encore d'ID — on utilise un UUID temporaire
      // (DateTime epoch en hex). En EDIT on utilise l'ID existant.
      final productId = _existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toRadixString(16);
      final url = await ServiceLocator.menuDataSource.uploadProductPhoto(
        ownerUid: ownerUid,
        productId: productId,
        bytes: compressed,
      );
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload échoué : $e')),
      );
    }
  }

  // ─── Save ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
      final now = DateTime.now();
      final entity = ProductEntity(
        id: _existing?.id ?? '',
        restaurantId: widget.restaurantId,
        categoryId: widget.categoryId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: price,
        mainImageUrl: _photoUrl,
        allergens: _allergens.toList(),
        labels: _labels.toList(),
        isAvailable: _isAvailable,
        estimatedPreparationTime: _prepTime,
        createdAt: _existing?.createdAt ?? now,
        updatedAt: now,
      );
      if (_isEdit) {
        await ServiceLocator.menuDataSource.updateProduct(entity);
      } else {
        await ServiceLocator.menuDataSource.createProduct(entity);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sauvegarde échouée : $e')),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = _existing?.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le produit ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ServiceLocator.menuDataSource.deleteProduct(id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression échouée : $e')),
      );
      setState(() => _saving = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Produit'),
          leading: const BackButton(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEdit ? 'Modifier le produit' : 'Nouveau produit'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _saving ? null : _delete,
              tooltip: 'Supprimer',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _photoSection(),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du produit *',
                prefixIcon: Icon(Icons.fastfood),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Description *',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix *',
                prefixIcon: Icon(Icons.euro),
                suffixText: '€',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n < 0) return 'Prix invalide';
                return null;
              },
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Allergènes'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in Allergen.values)
                  FilterChip(
                    label: Text(a.displayName,
                        style: const TextStyle(fontSize: 11)),
                    selected: _allergens.contains(a),
                    onSelected: (sel) => setState(() {
                      sel ? _allergens.add(a) : _allergens.remove(a);
                    }),
                    selectedColor: Colors.red.shade100,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Labels'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in ProductLabel.values)
                  FilterChip(
                    label: Text(l.displayName,
                        style: const TextStyle(fontSize: 11)),
                    selected: _labels.contains(l),
                    onSelected: (sel) => setState(() {
                      sel ? _labels.add(l) : _labels.remove(l);
                    }),
                    selectedColor: Colors.green.shade100,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Paramètres'),
            const SizedBox(height: 4),
            SwitchListTile(
              title: const Text('Disponible'),
              subtitle: const Text(
                  'Décocher pour rupture stock (caché côté Client)'),
              value: _isAvailable,
              onChanged: (v) => setState(() => _isAvailable = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Text('Temps de préparation : $_prepTime min'),
            Slider(
              value: _prepTime.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              label: '$_prepTime min',
              onChanged: (v) => setState(() => _prepTime = v.round()),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_isEdit ? 'Enregistrer' : 'Créer le produit'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploadingPhoto ? null : _pickPhoto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if ((_photoUrl ?? '').isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: _photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    else
                      _placeholder(),
                    if (_uploadingPhoto)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _uploadingPhoto ? null : _pickPhoto,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: Text((_photoUrl ?? '').isNotEmpty
                ? 'Changer la photo'
                : 'Ajouter une photo'),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
