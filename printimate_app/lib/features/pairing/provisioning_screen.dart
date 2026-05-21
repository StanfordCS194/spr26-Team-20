import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../onboarding/onboarding_state.dart';

// Demo shortcut: matches PRINTIMATE_DEMO_FIXED_POP in firmware/include/config.h.
// Replace with per-device PoP delivered via QR code before any real release.
const _kDemoPop = 'printimate';

// All Printimate printers advertise as "PROV_<pid>".
const _kBleNamePrefix = 'PROV_';

/// True only on platforms where BLE provisioning is possible.
/// flutter_esp_ble_prov ships native iOS + Android implementations only.
bool get _bleProvisioningSupported {
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isAndroid;
}

enum _Step {
  scanning,
  pickDevice,
  scanningWifi,
  pickWifi,
  enterPassword,
  provisioning,
  success,
  error,
}

class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  final _ble = FlutterEspBleProv();
  final _passwordCtl = TextEditingController();

  _Step _step = _Step.scanning;
  List<String> _devices = const [];
  List<String> _wifiNetworks = const [];
  String? _selectedDevice;
  String? _selectedSsid;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (_bleProvisioningSupported) {
      _startScan();
    }
  }

  @override
  void dispose() {
    _passwordCtl.dispose();
    super.dispose();
  }

  String _parsePid(String deviceName) =>
      deviceName.startsWith(_kBleNamePrefix)
          ? deviceName.substring(_kBleNamePrefix.length)
          : deviceName;

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<void> _startScan() async {
    setState(() {
      _step = _Step.scanning;
      _errorMessage = '';
    });
    final ok = await _ensurePermissions();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _step = _Step.error;
        _errorMessage =
            'Bluetooth permission is required to find your printer.';
      });
      return;
    }
    try {
      final devices = await _ble.scanBleDevices(_kBleNamePrefix);
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _step = _Step.pickDevice;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _errorMessage = 'BLE scan failed: $e';
      });
    }
  }

  Future<void> _pickDevice(String deviceName) async {
    setState(() {
      _selectedDevice = deviceName;
      _step = _Step.scanningWifi;
      _errorMessage = '';
    });
    try {
      final networks = await _ble.scanWifiNetworks(deviceName, _kDemoPop);
      if (!mounted) return;
      setState(() {
        _wifiNetworks = networks;
        _step = _Step.pickWifi;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _errorMessage =
            'Couldn\'t talk to printer. It may already be paired — '
            'long-press the BOOT button on the printer for 5 seconds to reset, '
            'then try again.\n\n$e';
      });
    }
  }

  void _pickSsid(String ssid) {
    setState(() {
      _selectedSsid = ssid;
      _passwordCtl.clear();
      _step = _Step.enterPassword;
    });
  }

  Future<void> _submitCredentials() async {
    final device = _selectedDevice;
    final ssid = _selectedSsid;
    if (device == null || ssid == null) return;
    setState(() {
      _step = _Step.provisioning;
      _errorMessage = '';
    });
    try {
      final ok = await _ble.provisionWifi(
        device,
        _kDemoPop,
        ssid,
        _passwordCtl.text,
      );
      if (!mounted) return;
      if (ok == true) {
        ref.read(onboardingProvider.notifier).setPrinterId(_parsePid(device));
        setState(() => _step = _Step.success);
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        context.go('/home');
      } else {
        setState(() {
          _step = _Step.error;
          _errorMessage =
              'Printer rejected the credentials. Check the Wi-Fi password and try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _errorMessage = 'Provisioning failed: $e';
      });
    }
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
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2),
        ),
      ),
      body: SafeArea(
        child: _bleProvisioningSupported
            ? _SupportedBody(
                step: _step,
                devices: _devices,
                wifiNetworks: _wifiNetworks,
                selectedDevice: _selectedDevice,
                selectedSsid: _selectedSsid,
                passwordCtl: _passwordCtl,
                errorMessage: _errorMessage,
                onRescan: _startScan,
                onPickDevice: _pickDevice,
                onPickSsid: _pickSsid,
                onSubmitCreds: _submitCredentials,
                onRetry: _startScan,
                parsePid: _parsePid,
              )
            : _UnsupportedBody(showCancel: canPop),
      ),
    );
  }
}

class _SupportedBody extends StatelessWidget {
  const _SupportedBody({
    required this.step,
    required this.devices,
    required this.wifiNetworks,
    required this.selectedDevice,
    required this.selectedSsid,
    required this.passwordCtl,
    required this.errorMessage,
    required this.onRescan,
    required this.onPickDevice,
    required this.onPickSsid,
    required this.onSubmitCreds,
    required this.onRetry,
    required this.parsePid,
  });

  final _Step step;
  final List<String> devices;
  final List<String> wifiNetworks;
  final String? selectedDevice;
  final String? selectedSsid;
  final TextEditingController passwordCtl;
  final String errorMessage;
  final VoidCallback onRescan;
  final ValueChanged<String> onPickDevice;
  final ValueChanged<String> onPickSsid;
  final VoidCallback onSubmitCreds;
  final VoidCallback onRetry;
  final String Function(String) parsePid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: switch (step) {
        _Step.scanning => _StatusCard(
            icon: Icons.bluetooth_searching,
            title: 'LOOKING FOR PRINTERS',
            body:
                'Make sure your printer is plugged in and powered on. It advertises over Bluetooth for the first minute after boot.',
            spinner: true,
          ),
        _Step.pickDevice => _DeviceList(
            devices: devices,
            onPick: onPickDevice,
            onRescan: onRescan,
            parsePid: parsePid,
          ),
        _Step.scanningWifi => _StatusCard(
            icon: Icons.wifi_find,
            title: 'ASKING PRINTER FOR WI-FI LIST',
            body:
                'Talking to ${parsePid(selectedDevice ?? '')} over Bluetooth...',
            spinner: true,
          ),
        _Step.pickWifi => _WifiList(
            ssids: wifiNetworks,
            onPick: onPickSsid,
            onRescan: onRescan,
          ),
        _Step.enterPassword => _PasswordForm(
            ssid: selectedSsid ?? '',
            controller: passwordCtl,
            onSubmit: onSubmitCreds,
          ),
        _Step.provisioning => _StatusCard(
            icon: Icons.wifi_tethering,
            title: 'CONFIGURING PRINTER',
            body:
                'Sending Wi-Fi credentials to ${parsePid(selectedDevice ?? '')}. This usually takes about 10 seconds.',
            spinner: true,
          ),
        _Step.success => _StatusCard(
            icon: Icons.check_circle_outline,
            title: 'PAIRED!',
            body:
                '${parsePid(selectedDevice ?? '')} is now linked to your account.',
            spinner: false,
          ),
        _Step.error => _ErrorBody(
            message: errorMessage,
            onRetry: onRetry,
          ),
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.spinner,
  });
  final IconData icon;
  final String title;
  final String body;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: PrintimateColors.surface,
          border: Border.all(color: PrintimateColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: PrintimateColors.text),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (spinner) ...[
              const SizedBox(height: 20),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.devices,
    required this.onPick,
    required this.onRescan,
    required this.parsePid,
  });
  final List<String> devices;
  final ValueChanged<String> onPick;
  final VoidCallback onRescan;
  final String Function(String) parsePid;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusCard(
            icon: Icons.search_off,
            title: 'NO PRINTERS FOUND',
            body:
                'Couldn\'t find any Printimate printers advertising nearby. Make sure your printer is powered on and within ~10 feet, then try again.',
            spinner: false,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onRescan,
            child: const Text('SCAN AGAIN  ⟳'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('SELECT A PRINTER',
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 2)),
        const SizedBox(height: 4),
        Text('${devices.length} found nearby',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: devices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final name = devices[i];
              final pid = parsePid(name);
              return Material(
                color: PrintimateColors.surface,
                child: InkWell(
                  onTap: () => onPick(name),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: PrintimateColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.print, color: PrintimateColors.text),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pid,
                                  style: Theme.of(context).textTheme.bodyLarge),
                              const SizedBox(height: 2),
                              Text(name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: PrintimateColors.textDim)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: PrintimateColors.textDim),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onRescan,
          child: const Text('SCAN AGAIN  ⟳',
              style: TextStyle(
                  color: PrintimateColors.textDim, letterSpacing: 1.5)),
        ),
      ],
    );
  }
}

class _WifiList extends StatelessWidget {
  const _WifiList({
    required this.ssids,
    required this.onPick,
    required this.onRescan,
  });
  final List<String> ssids;
  final ValueChanged<String> onPick;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    if (ssids.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusCard(
            icon: Icons.wifi_off,
            title: 'NO WI-FI NETWORKS',
            body:
                'The printer didn\'t see any Wi-Fi networks. Move closer to your router and try again.',
            spinner: false,
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRescan, child: const Text('START OVER ⟳')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('SELECT A WI-FI NETWORK',
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 2)),
        const SizedBox(height: 4),
        Text('Visible to the printer',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: ssids.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final ssid = ssids[i];
              return Material(
                color: PrintimateColors.surface,
                child: InkWell(
                  onTap: () => onPick(ssid),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: PrintimateColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi, color: PrintimateColors.text),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(ssid,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ),
                        const Icon(Icons.chevron_right,
                            color: PrintimateColors.textDim),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm({
    required this.ssid,
    required this.controller,
    required this.onSubmit,
  });
  final String ssid;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('WI-FI PASSWORD',
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(widget.ssid, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Password',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off,
                  color: PrintimateColors.textDim),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onSubmitted: (_) => widget.onSubmit(),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: widget.onSubmit,
          child: const Text('CONNECT PRINTER  →'),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

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
              const Icon(Icons.error_outline,
                  size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text('SOMETHING WENT WRONG',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        letterSpacing: 2,
                        color: Colors.redAccent,
                      )),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: onRetry, child: const Text('TRY AGAIN  ⟳')),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
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
            Builder(
              builder: (context) => OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('GO BACK  ←'),
              ),
            )
          else
            Builder(
              builder: (context) => OutlinedButton(
                onPressed: () => context.go('/home'),
                child: const Text('CONTINUE TO APP  →'),
              ),
            ),
        ],
      ),
    );
  }
}
