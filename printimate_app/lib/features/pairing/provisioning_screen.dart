import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../onboarding/onboarding_state.dart';

/// True only on platforms where BLE provisioning is possible.
/// flutter_esp_ble_prov ships native iOS + Android implementations only.
bool get _bleProvisioningSupported {
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isAndroid;
}

/// Stub provisioning screen. Real BLE flow (flutter_esp_ble_prov) lands later.
class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  final _pidCtl = TextEditingController();
  bool _scanning = false;

  @override
  void dispose() {
    _pidCtl.dispose();
    super.dispose();
  }

  Future<void> _fakeScan() async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _scanning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: PrintimateColors.surface,
        content: Text(
          'BLE scan is not wired up yet. Enter a printer ID below to continue.',
        ),
      ),
    );
  }

  void _save() {
    final pid = _pidCtl.text.trim();
    if (pid.isEmpty) return;
    ref.read(onboardingProvider.notifier).setPrinterId(pid);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PrintimateColors.background,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: PrintimateColors.text),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          'PAIR A PRINTER',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _bleProvisioningSupported
              ? _SupportedBody(
                  pidCtl: _pidCtl,
                  scanning: _scanning,
                  onScan: _fakeScan,
                  onSave: _save,
                  showCancel: canPop,
                )
              : _UnsupportedBody(showCancel: canPop),
        ),
      ),
    );
  }
}

class _SupportedBody extends StatelessWidget {
  const _SupportedBody({
    required this.pidCtl,
    required this.scanning,
    required this.onScan,
    required this.onSave,
    required this.showCancel,
  });
  final TextEditingController pidCtl;
  final bool scanning;
  final VoidCallback onScan;
  final VoidCallback onSave;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: PrintimateColors.surface,
            border: Border.all(color: PrintimateColors.border),
          ),
          child: Column(
            children: [
              const Icon(Icons.bluetooth_searching,
                  size: 56, color: PrintimateColors.text),
              const SizedBox(height: 16),
              Text(
                'Looking for printers nearby...',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure your printer is plugged in and powered on.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: scanning ? null : onScan,
                child: Text(scanning ? 'SCANNING...' : 'SCAN  ⟳'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            const Expanded(child: Divider(color: PrintimateColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR', style: Theme.of(context).textTheme.bodyMedium),
            ),
            const Expanded(child: Divider(color: PrintimateColors.border)),
          ],
        ),
        const SizedBox(height: 24),
        Text('PRINTER ID', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: pidCtl,
          decoration: const InputDecoration(hintText: 'prn_unitA'),
          onSubmitted: (_) => onSave(),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: onSave,
          child: const Text('USE THIS PRINTER  →'),
        ),
        const SizedBox(height: 12),
        if (showCancel)
          TextButton(
            onPressed: () => context.pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: PrintimateColors.textDim, letterSpacing: 1.5),
            ),
          ),
      ],
    );
  }
}

class _UnsupportedBody extends StatelessWidget {
  const _UnsupportedBody({required this.showCancel});
  final bool showCancel;

  String get _platformName {
    if (kIsWeb) return 'the web';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'this platform';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: PrintimateColors.surface,
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              const Icon(Icons.bluetooth_disabled,
                  size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'BLUETOOTH PAIRING UNAVAILABLE',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      letterSpacing: 2,
                      color: Colors.redAccent,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Printer pairing isn\'t supported on $_platformName.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Open Printimate on an iPhone or Android device to pair a printer.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (showCancel)
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('GO BACK  ←'),
          )
        else
          OutlinedButton(
            onPressed: () => context.go('/home'),
            child: const Text('CONTINUE TO APP  →'),
          ),
      ],
    );
  }
}
