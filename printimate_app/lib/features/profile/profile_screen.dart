import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../auth/auth_controller.dart';
import 'profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _picker = ImagePicker();
  bool _uploadingAvatar = false;
  String? _error;

  Future<void> _editName(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PrintimateColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('EDIT NAME', style: Theme.of(context).textTheme.titleLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL',
                style: TextStyle(color: PrintimateColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('SAVE',
                style: TextStyle(color: PrintimateColors.text)),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(profileRepositoryProvider).updateDisplayName(result);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save name: $e');
    }
  }

  Future<void> _changePhoto() async {
    setState(() => _error = null);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
      );
      if (picked == null) return;
      setState(() => _uploadingAvatar = true);
      final raw = await picked.readAsBytes();
      final processed = await _resizeSquare(raw, 512);
      await ref.read(profileRepositoryProvider).uploadAvatar(processed);
    } catch (e) {
      if (mounted) setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider).signOut();
    if (mounted) context.go('/intro');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(profileRepositoryProvider);

    return SafeArea(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: repo.watchCurrentProfile(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final displayName = (data['displayName'] as String?) ?? '';
          final email = data['email'] as String?;
          final phone = data['phoneNumber'] as String?;
          final photoUrl = data['photoURL'] as String?;
          final providerIds =
              (data['providerIds'] as List?)?.cast<String>() ?? const [];
          final emailVerified = data['emailVerified'] == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('PROFILE',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Divider(color: PrintimateColors.border, height: 1),
                const SizedBox(height: 32),
                Center(
                  child: _AvatarPicker(
                    photoUrl: photoUrl,
                    busy: _uploadingAvatar,
                    onTap: _uploadingAvatar ? null : _changePhoto,
                  ),
                ),
                const SizedBox(height: 32),
                _Field(
                  label: 'NAME',
                  value: displayName.isEmpty ? '—' : displayName,
                  onEdit: () => _editName(displayName),
                ),
                _Field(
                  label: 'EMAIL',
                  value: email ?? '—',
                  trailing: emailVerified
                      ? const Text('VERIFIED',
                          style: TextStyle(
                            color: PrintimateColors.textDim,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ))
                      : null,
                ),
                if (phone != null && phone.isNotEmpty)
                  _Field(label: 'PHONE', value: phone),
                _Field(
                  label: 'SIGN-IN METHODS',
                  value: providerIds.isEmpty
                      ? '—'
                      : providerIds.map(_prettyProvider).join(', '),
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 16),
                ],
                OutlinedButton(
                  onPressed: _signOut,
                  child: const Text('SIGN OUT  →'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _prettyProvider(String id) {
  switch (id) {
    case 'password':
      return 'Email';
    case 'google.com':
      return 'Google';
    case 'apple.com':
      return 'Apple';
    default:
      return id;
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.photoUrl,
    required this.busy,
    required this.onTap,
  });
  final String? photoUrl;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: PrintimateColors.surface,
              border: Border.all(color: PrintimateColors.border),
            ),
            child: hasPhoto
                ? Image.network(photoUrl!, fit: BoxFit.cover)
                : const Icon(Icons.person_outline,
                    size: 64, color: PrintimateColors.textDim),
          ),
          Positioned.fill(
            child: Container(
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.black.withValues(alpha: 0.6),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PrintimateColors.text,
                      ),
                    )
                  : const Text(
                      'CHANGE',
                      style: TextStyle(
                        color: PrintimateColors.text,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.onEdit,
    this.trailing,
  });
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PrintimateColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: PrintimateColors.textDim),
            ),
        ],
      ),
    );
  }
}

Future<Uint8List> _resizeSquare(Uint8List raw, int size) async {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;
  final shorter = decoded.width < decoded.height ? decoded.width : decoded.height;
  final cropped = img.copyCrop(
    decoded,
    x: (decoded.width - shorter) ~/ 2,
    y: (decoded.height - shorter) ~/ 2,
    width: shorter,
    height: shorter,
  );
  final resized = img.copyResize(cropped, width: size, height: size);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
}
