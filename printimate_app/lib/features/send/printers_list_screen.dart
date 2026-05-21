import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/theme.dart';
import '../onboarding/onboarding_state.dart';
import '../send/send_screen.dart';

const String _defaultServerUrl = 'https://printimate-35d0d5bebe8d.herokuapp.com';

/// A single printer entry returned by the backend.
class _Printer {
  final String pid;
  const _Printer({required this.pid});
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PrintersListScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onPrinterSelected;
  const PrintersListScreen({super.key, required this.onPrinterSelected});

  @override
  ConsumerState<PrintersListScreen> createState() => _PrintersListScreenState();
}

class _PrintersListScreenState extends ConsumerState<PrintersListScreen> {
  final List<_Printer> _printers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _printers
            ..clear()
            ..addAll(const [_Printer(pid: 'printer1')]);
          _error = 'Sign in to view your printers.';
          _loading = false;
        });
        return;
      }

      final response = await http
          .post(
            Uri.parse('$_defaultServerUrl/printers-list'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': user.uid}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final printerIds = (data['printers'] as List? ?? const [])
          .cast<dynamic>()
          .map((value) => value.toString())
          .toList();

      setState(() {
        _printers
          ..clear()
          ..addAll(printerIds.map((pid) => _Printer(pid: pid)));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _printers
          ..clear()
          ..addAll(const [_Printer(pid: 'printer1')]);
        _error = 'Could not load printers (offline or server error).';
        _loading = false;
      });
      debugPrint('Failed to load printers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  const Icon(Icons.print_outlined, color: PrintimateColors.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PRINTERS LIST',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: PrintimateColors.border, height: 1),

            // ── Sub-header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 14, color: PrintimateColors.textDim),
                  const SizedBox(width: 8),
                  Text(
                    'Select a printer to message',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: PrintimateColors.textDim,
                        ),
                  ),
                ],
              ),
            ),

            const Divider(color: PrintimateColors.border, height: 1),

            // ── Printer's list ───────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PrintimateColors.text,
                        ),
                      ),
                    )
                  : _printers.isEmpty
                      ? const _EmptyState()
                      : Column(
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        size: 14, color: PrintimateColors.textDim),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: PrintimateColors.textDim,
                                            ),
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: _loadPrinters,
                                      child: const Text('RETRY'),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _loadPrinters,
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: _printers.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    color: PrintimateColors.border,
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) => _PrinterTile(
                                    printer: _printers[index],
                                    onTap: () => widget.onPrinterSelected(_printers[index].pid),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Printer tile
// ---------------------------------------------------------------------------

class _PrinterTile extends StatelessWidget {
  const _PrinterTile({required this.printer, required this.onTap});

  final _Printer printer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            const Icon(Icons.print_outlined,
                size: 20, color: PrintimateColors.textDim),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                printer.pid,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.print_disabled_outlined,
              size: 36, color: PrintimateColors.textDim),
          const SizedBox(height: 16),
          Text(
            'NO PRINTERS YET',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: PrintimateColors.textDim,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Owned or friended printers will show up here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PrintimateColors.textDim,
                ),
          ),
        ],
      ),
    );
  }
}
