import 'package:flutter/material.dart';

class PairingScreen extends StatelessWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair a printer')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pairing flow will live here:\n1. Scan QR on printer\n2. BLE-provision WiFi credentials\n3. Name the printer',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
