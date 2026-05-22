import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import 'package:flutter/foundation.dart';

class _Suggestion {
  const _Suggestion(this.id, this.name);
  final String id;
  final String name;
}

class FriendingScreen extends StatefulWidget {
  const FriendingScreen({super.key});

  @override
  State<FriendingScreen> createState() => _FriendingScreenState();
}

class _FriendingScreenState extends State<FriendingScreen> {
  final _selected = <String>{};
  List<_Suggestion> _suggestions = [];
  bool _loading = true;
  bool _permissionDenied = false;
  bool _notMobile = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
     if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    setState(() {
      _notMobile = true;
      _loading = false;
    });
    return;
    }
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      return;
    }

    final contacts = await FlutterContacts.getContacts(withProperties: false);
    setState(() {
      _suggestions = contacts
          .map((c) => _Suggestion(c.id, c.displayName))
          .where((s) => s.name.isNotEmpty)
          .toList();
      _loading = false;
    });
  }

  void _finish() => context.go('/');

  @override
  Widget build(BuildContext context) {
    Widget listContent;
    if (_loading) {
      listContent = const Center(child: CircularProgressIndicator());
    } else if (_notMobile) {
      listContent = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_iphone, size: 48, color: PrintimateColors.textDim),
            const SizedBox(height: 16),
            Text(
              'MOBILE APP REQUIRED',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: PrintimateColors.textDim),
            ),
            const SizedBox(height: 8),
            Text(
              'Download Printimate on iOS or Android\nto sync your contacts.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: PrintimateColors.textDim),
            ),
          ],
        ),
      );
    } else if (_permissionDenied) {
      listContent = Center(
        child: Text(
          'Contacts permission denied.\nYou can add friends later.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: PrintimateColors.textDim),
        ),
      );
    } else if (_suggestions.isEmpty) {
      listContent = const Center(child: Text('No contacts found.'));
    } else {
      listContent = ListView.separated(
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s = _suggestions[i];
          final selected = _selected.contains(s.id);
          return InkWell(
            onTap: () => setState(() {
              selected ? _selected.remove(s.id) : _selected.add(s.id);
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: PrintimateColors.surface,
                border: Border.all(
                  color: selected ? PrintimateColors.text : PrintimateColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                    color: PrintimateColors.text,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PrintimateColors.background,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: PrintimateColors.text),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          'ADD FRIENDS',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2),
        ),
      ),  
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('SELECT FRIENDS',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                'Choose contacts who have receipt printers',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              Expanded(child: listContent),

              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _selected.isEmpty ? null : _finish,
                child: Text('ADD ${_selected.length} FRIENDS'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _finish,
                child: const Text('SKIP FOR NOW'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}