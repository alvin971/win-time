import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../widgets/business_hours_editor.dart';
import '../widgets/photo_upload_field.dart';

/// Page "Mon Restaurant" — CRUD du restaurant du commerçant connecté.
///
/// Mode CREATE si aucun resto n'est associé (user vient de l'empty state),
/// mode EDIT sinon. Détection automatique au launch via
/// [SupabaseRestaurantDataSource.getMyRestaurant].
///
/// Form en 7 sections (toutes scrollables dans une seule page) :
/// 1. Infos basiques (nom, slogan, description, cuisine, prix)
/// 2. Adresse (street, city, postal, lat/lng + bouton "ma position")
/// 3. Contact (email, phone, website)
/// 4. Réseaux sociaux (collapsible)
/// 5. Horaires (BusinessHoursEditor 7j)
/// 6. Photos (logo + banner)
/// 7. Paramètres (acceptingOrders, prepTime, isActive)
class MyRestaurantPage extends StatefulWidget {
  /// Si non-null, on charge ce resto en EDIT. Sinon on tente de récupérer
  /// le resto possédé par le user, et bascule en CREATE si rien.
  final String? restaurantId;
  const MyRestaurantPage({super.key, this.restaurantId});

  @override
  State<MyRestaurantPage> createState() => _MyRestaurantPageState();
}

class _MyRestaurantPageState extends State<MyRestaurantPage> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _isCreate = false;
  String? _existingId;
  String? _error;

  // Form state
  final _nameCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  CuisineType _cuisineType = CuisineType.french;
  PriceRange _priceRange = PriceRange.moderate;

  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'France');
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();

  BusinessHours _businessHours = BusinessHours.allClosed();
  String? _logoUrl;
  String? _bannerUrl;
  List<String> _galleryImages = const [];

  bool _acceptingOrders = true;
  bool _isActive = true;
  int _avgPrepTime = 30;

  // Auth user
  late final String _ownerUid;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _ownerUid = user?.id ?? '';
    _bootstrap();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _sloganCtrl, _descriptionCtrl,
      _streetCtrl, _cityCtrl, _postalCtrl, _countryCtrl, _latCtrl, _lngCtrl,
      _emailCtrl, _phoneCtrl, _websiteCtrl,
      _facebookCtrl, _instagramCtrl, _twitterCtrl, _tiktokCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Load existing restaurant ───────────────────────────────────────────

  Future<void> _bootstrap() async {
    try {
      final row = await ServiceLocator.restaurantDataSource
          .getMyRestaurant(_ownerUid);
      if (!mounted) return;
      if (row == null) {
        // Mode CREATE — on initialise les valeurs par défaut
        setState(() {
          _isCreate = true;
          _businessHours = _defaultHours();
          _loading = false;
        });
        return;
      }
      // Mode EDIT — on charge les valeurs depuis la row
      final entity = RestaurantModel.fromRow(row);
      _existingId = entity.id;
      _nameCtrl.text = entity.name;
      _sloganCtrl.text = entity.slogan ?? '';
      _descriptionCtrl.text = entity.description ?? '';
      _cuisineType = entity.cuisineType;
      _priceRange = entity.priceRange;
      _streetCtrl.text = entity.address.street;
      _cityCtrl.text = entity.address.city;
      _postalCtrl.text = entity.address.postalCode;
      _countryCtrl.text = entity.address.country;
      _latCtrl.text = entity.address.latitude.toString();
      _lngCtrl.text = entity.address.longitude.toString();
      _emailCtrl.text = entity.contactInfo.email;
      _phoneCtrl.text = entity.contactInfo.phoneNumber;
      _websiteCtrl.text = entity.contactInfo.websiteUrl ?? '';
      _facebookCtrl.text = entity.socialLinks?.facebook ?? '';
      _instagramCtrl.text = entity.socialLinks?.instagram ?? '';
      _twitterCtrl.text = entity.socialLinks?.twitter ?? '';
      _tiktokCtrl.text = entity.socialLinks?.tiktok ?? '';
      _businessHours = entity.businessHours;
      _logoUrl = entity.logoUrl;
      _bannerUrl = entity.bannerUrl;
      _galleryImages = entity.galleryImages;
      _acceptingOrders = entity.acceptingOrders;
      _isActive = entity.isActive;
      _avgPrepTime = entity.averagePreparationTime;
      setState(() {
        _isCreate = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Chargement échoué : $e';
      });
    }
  }

  BusinessHours _defaultHours() {
    final slot = const TimeSlot(openTime: '11:00', closeTime: '23:00');
    return BusinessHours(schedule: {
      for (final d in DayOfWeek.values)
        d: DaySchedule(isOpen: true, morning: slot),
    });
  }

  // ─── Geolocation ────────────────────────────────────────────────────────

  Future<void> _useMyPosition() async {
    final perm = await Permission.location.request();
    if (!perm.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission de localisation refusée')),
        );
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Position indisponible : $e')),
        );
      }
    }
  }

  // ─── Save ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude/longitude invalides')),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final entity = RestaurantEntity(
        id: _existingId ?? '',
        ownerId: _ownerUid,
        name: _nameCtrl.text.trim(),
        slogan: _sloganCtrl.text.trim().isEmpty ? null : _sloganCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        cuisineType: _cuisineType,
        priceRange: _priceRange,
        address: AddressEntity(
          street: _streetCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          postalCode: _postalCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          latitude: lat,
          longitude: lng,
        ),
        contactInfo: ContactInfo(
          email: _emailCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          websiteUrl: _websiteCtrl.text.trim().isEmpty
              ? null
              : _websiteCtrl.text.trim(),
        ),
        socialLinks: SocialLinks(
          facebook: _facebookCtrl.text.trim().isEmpty ? null : _facebookCtrl.text.trim(),
          instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
          twitter: _twitterCtrl.text.trim().isEmpty ? null : _twitterCtrl.text.trim(),
          tiktok: _tiktokCtrl.text.trim().isEmpty ? null : _tiktokCtrl.text.trim(),
        ),
        logoUrl: _logoUrl,
        bannerUrl: _bannerUrl,
        galleryImages: _galleryImages,
        businessHours: _businessHours,
        isActive: _isActive,
        // Pour la démo on auto-approve. En vrai prod ce serait validé par
        // un admin via une back-office.
        isApproved: true,
        acceptingOrders: _acceptingOrders,
        averagePreparationTime: _avgPrepTime,
        geohash: '', // recalculé par RestaurantModel.toRow
        createdAt: _existingId == null ? now : now, // toRow ignore createdAt si on update
        updatedAt: now,
      );
      final row = RestaurantModel.toRow(entity);
      // toRow envoie 'id' si non-vide ; pour create on l'omet (Postgres génère)
      if (_isCreate) {
        row.remove('id');
        final newId = await ServiceLocator.restaurantDataSource.createRestaurant(row);
        _existingId = newId;
        ServiceLocator.currentRestaurantId = newId;
      } else {
        await ServiceLocator.restaurantDataSource.updateRestaurant(
          id: _existingId!,
          row: row,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isCreate ? 'Restaurant créé !' : 'Modifications enregistrées')),
      );
      Navigator.of(context).pop(true); // signale au caller que ça a sauvé
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec sauvegarde : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon Restaurant')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon Restaurant')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        )),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'Créer mon restaurant' : 'Mon Restaurant'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: '1. Infos basiques',
              icon: Icons.info_outline,
              child: _basicSection(),
            ),
            _Section(
              title: '2. Adresse',
              icon: Icons.location_on_outlined,
              child: _addressSection(),
            ),
            _Section(
              title: '3. Contact',
              icon: Icons.contact_mail_outlined,
              child: _contactSection(),
            ),
            _Section(
              title: '4. Réseaux sociaux',
              icon: Icons.share_outlined,
              initiallyExpanded: false,
              child: _socialSection(),
            ),
            _Section(
              title: '5. Horaires',
              icon: Icons.schedule_outlined,
              child: BusinessHoursEditor(
                initial: _businessHours,
                onChanged: (h) => _businessHours = h,
              ),
            ),
            _Section(
              title: '6. Photos',
              icon: Icons.photo_outlined,
              child: _photosSection(),
            ),
            _Section(
              title: '7. Paramètres',
              icon: Icons.settings_outlined,
              child: _settingsSection(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isCreate ? 'Créer le restaurant' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section builders ──────────────────────────────────────────────────

  Widget _basicSection() {
    return Column(
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom du restaurant *',
            prefixIcon: Icon(Icons.storefront),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _sloganCtrl,
          decoration: const InputDecoration(
            labelText: 'Slogan (optionnel)',
            prefixIcon: Icon(Icons.format_quote),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionCtrl,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Description',
            prefixIcon: Icon(Icons.description_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CuisineType>(
          value: _cuisineType,
          decoration: const InputDecoration(
            labelText: 'Type de cuisine',
            prefixIcon: Icon(Icons.local_dining),
          ),
          items: [
            for (final c in CuisineType.values)
              DropdownMenuItem(value: c, child: Text(c.displayName)),
          ],
          onChanged: (v) => setState(() => _cuisineType = v ?? CuisineType.other),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Gamme de prix', style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final p in PriceRange.values)
              ChoiceChip(
                label: Text('${p.symbol}\n${_priceRangeLabel(p)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11)),
                selected: _priceRange == p,
                onSelected: (_) => setState(() => _priceRange = p),
              ),
          ],
        ),
      ],
    );
  }

  String _priceRangeLabel(PriceRange p) {
    switch (p) {
      case PriceRange.budget:
        return 'Économique';
      case PriceRange.moderate:
        return 'Modéré';
      case PriceRange.expensive:
        return 'Cher';
      case PriceRange.luxury:
        return 'Luxe';
    }
  }

  Widget _addressSection() {
    return Column(
      children: [
        TextFormField(
          controller: _streetCtrl,
          decoration: const InputDecoration(
            labelText: 'Rue *',
            prefixIcon: Icon(Icons.home_outlined),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _postalCtrl,
                decoration: const InputDecoration(
                  labelText: 'Code postal *',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ville *',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _countryCtrl,
          decoration: const InputDecoration(
            labelText: 'Pays',
            prefixIcon: Icon(Icons.public),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitude *',
                ),
                validator: (v) => double.tryParse(v ?? '') == null ? 'Nombre' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _lngCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitude *',
                ),
                validator: (v) => double.tryParse(v ?? '') == null ? 'Nombre' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _useMyPosition,
          icon: const Icon(Icons.my_location),
          label: const Text('Utiliser ma position actuelle'),
        ),
      ],
    );
  }

  Widget _contactSection() {
    return Column(
      children: [
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email *',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (v) =>
              v == null || !v.contains('@') ? 'Email invalide' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Téléphone *',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (v) =>
              v == null || v.trim().length < 8 ? 'Téléphone trop court' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _websiteCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Site web (optionnel)',
            prefixIcon: Icon(Icons.language),
          ),
        ),
      ],
    );
  }

  Widget _socialSection() {
    return Column(
      children: [
        for (final entry in [
          ('Facebook', _facebookCtrl, Icons.facebook),
          ('Instagram', _instagramCtrl, Icons.camera_alt_outlined),
          ('Twitter / X', _twitterCtrl, Icons.alternate_email),
          ('TikTok', _tiktokCtrl, Icons.music_note),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: entry.$2,
              decoration: InputDecoration(
                labelText: entry.$1,
                prefixIcon: Icon(entry.$3),
              ),
            ),
          ),
      ],
    );
  }

  Widget _photosSection() {
    return Column(
      children: [
        PhotoUploadField(
          label: 'Logo (carré)',
          currentUrl: _logoUrl,
          ownerUid: _ownerUid,
          kind: 'logo',
          dataSource: ServiceLocator.restaurantDataSource,
          onUploaded: (url) => setState(() => _logoUrl = url),
          aspectRatio: 1,
        ),
        const SizedBox(height: 16),
        PhotoUploadField(
          label: 'Bannière (16:9)',
          currentUrl: _bannerUrl,
          ownerUid: _ownerUid,
          kind: 'banner',
          dataSource: ServiceLocator.restaurantDataSource,
          onUploaded: (url) => setState(() => _bannerUrl = url),
          aspectRatio: 16 / 9,
        ),
      ],
    );
  }

  Widget _settingsSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Restaurant actif'),
          subtitle: const Text('Décocher pour masquer côté Client'),
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('Accepte les commandes'),
          subtitle: const Text('Toggle rapide ouverture/fermeture'),
          value: _acceptingOrders,
          onChanged: (v) => setState(() => _acceptingOrders = v),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Temps moyen de préparation : $_avgPrepTime min',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Slider(
          value: _avgPrepTime.toDouble(),
          min: 5,
          max: 60,
          divisions: 11,
          label: '$_avgPrepTime min',
          onChanged: (v) => setState(() => _avgPrepTime = v.round()),
        ),
      ],
    );
  }
}

// ─── Section accordion ─────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }
}
