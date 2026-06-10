import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/api.dart';



/// A single printer entry returned by the backend.
class _Printer {
  final String pid;

  /// Whether the current user owns this printer (vs. a friend's printer they
  /// were granted access to). Friended printers can be removed.
  final bool owned;
  const _Printer({required this.pid, this.owned = true});
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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _printers
            ..clear()
            ..addAll(const [_Printer(pid: 'printer1')]);
          _error = 'Sign in to view your printers.';
          _loading = false;
        });
        return;
      }

      final entries = await fetchPrintersDetailed(user.uid);

      setState(() {
        _printers
          ..clear()
          ..addAll(entries.isEmpty
              ? const [_Printer(pid: 'printer1')]
              : entries.map((e) => _Printer(pid: e.pid, owned: e.owned)));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _confirmRemove(_Printer printer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PrintimateColors.surface,
        title: const Text('Remove printer?'),
        content: Text(
          "You'll lose access to '${printer.pid}'. You can ask for access "
          'again later by sending a new request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await removeFriendedPrinter(user.uid, printer.pid);
      if (!mounted) return;
      setState(() => _printers.removeWhere((p) => p.pid == printer.pid));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Removed '${printer.pid}'")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove printer. Try again.')),
      );
      debugPrint('Failed to remove printer: $e');
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
                                  separatorBuilder: (_, _) => const Divider(
                                    color: PrintimateColors.border,
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) => _PrinterTile(
                                    printer: _printers[index],
                                    onTap: () => widget.onPrinterSelected(_printers[index].pid),
                                    onRemove: _printers[index].owned
                                        ? null
                                        : () => _confirmRemove(_printers[index]),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
            // ── Bottom buttons ───────────────────────────────────────────────
          const Divider(color: PrintimateColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_outlined, size: 16),
                      label: const Text("Add a friend's printer"),
                      onPressed: () => context.push('/friends'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/provisioning'),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Add my own printer'),
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
  const _PrinterTile({
    required this.printer,
    required this.onTap,
    this.onRemove,
  });

  final _Printer printer;
  final VoidCallback onTap;

  /// When non-null, a "remove" affordance is shown (friended printers only).
  final VoidCallback? onRemove;

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
            if (!printer.owned) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: PrintimateColors.border),
                ),
                child: const Text(
                  'FRIEND',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 10,
                    color: PrintimateColors.textDim,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
            if (onRemove != null)
              Tooltip(
                message: 'Remove printer',
                child: IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: PrintimateColors.textDim),
                  onPressed: onRemove,
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
