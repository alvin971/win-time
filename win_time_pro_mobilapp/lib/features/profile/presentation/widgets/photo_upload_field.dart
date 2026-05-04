import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/datasources/supabase_restaurant_datasource.dart';

/// Champ d'upload d'une photo unique (logo ou banner).
///
/// Tap → ImagePicker (caméra/galerie) → compression à <500 KB max-1080px
/// quality 80 → upload Supabase Storage via [SupabaseRestaurantDataSource]
/// → URL publique remontée via [onUploaded].
///
/// Affiche une preview de la photo (URL distante via cached_network_image
/// ou fichier local pendant l'upload).
class PhotoUploadField extends StatefulWidget {
  final String label;
  final String? currentUrl;
  final String ownerUid;

  /// 'logo' ou 'banner' (extensible vers gallery/<id> si besoin).
  final String kind;
  final SupabaseRestaurantDataSource dataSource;
  final ValueChanged<String> onUploaded;
  final double aspectRatio;

  const PhotoUploadField({
    super.key,
    required this.label,
    required this.currentUrl,
    required this.ownerUid,
    required this.kind,
    required this.dataSource,
    required this.onUploaded,
    this.aspectRatio = 1.0,
  });

  @override
  State<PhotoUploadField> createState() => _PhotoUploadFieldState();
}

class _PhotoUploadFieldState extends State<PhotoUploadField> {
  bool _uploading = false;
  File? _localPreview;

  Future<void> _pick() async {
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

    setState(() {
      _localPreview = File(picked.path);
      _uploading = true;
    });

    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 800,
        minHeight: 800,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) {
        throw Exception('Compression image échouée');
      }
      final ext = '${widget.kind}.jpg';
      final url = await widget.dataSource.uploadPhoto(
        ownerUid: widget.ownerUid,
        kind: ext,
        bytes: compressed,
        contentType: 'image/jpeg',
      );
      if (!mounted) return;
      widget.onUploaded(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.label} mise à jour')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec upload : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _preview() {
    if (_localPreview != null) {
      return Image.file(_localPreview!, fit: BoxFit.cover);
    }
    if (widget.currentUrl != null && widget.currentUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.currentUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.add_a_photo, size: 36, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _uploading ? null : _pick,
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _preview(),
                  if (_uploading)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
