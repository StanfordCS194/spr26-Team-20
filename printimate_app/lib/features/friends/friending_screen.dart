import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../app/theme.dart';
import '../auth/user_profile_repository.dart';
import '../onboarding/onboarding_state.dart';

const String _defaultServerUrl = 'https://printimate-35d0d5bebe8d.herokuapp.com';

class FriendingScreen extends ConsumerStatefulWidget {
  const FriendingScreen({super.key});

  @override
  ConsumerState<FriendingScreen> createState() => _FriendingScreenState();
}

class _FriendingScreenState extends ConsumerState<FriendingScreen> {
  final _pidCtl = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _successPid;

  // Previously used for contact/username flow — kept for future use
  final _selected = <String>{};
  final _usernameCtl = TextEditingController();
  List<_Suggestion> _suggestions = [];
  bool _loading = true;
  bool _permissionDenied = false;
  bool _notMobile = false;
  _Suggestion? _searchResult;
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    // _loadContacts(); // Uncomment to re-enable contact sync
  }

  @override
  void dispose() {
    _pidCtl.dispose();
    _usernameCtl.dispose();
    super.dispose();
  }

  // This function is currently unused
  // Previously Felipe was trying to load friends through contacts
  // Now we want to search printers by pid instead
  Future<void> _loadContacts() async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      setState(() { _notMobile = true; _loading = false; });
      return;
    }
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      setState(() { _permissionDenied = true; _loading = false; });
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

  // This function is currently unused
  // Previously Felipe was trying to get printers through username
  Future<void> _searchByUsername() async {
    final username = _usernameCtl.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _searching = true;
      _searchError = null;
      _searchResult = null;
    });

    final repo = ref.read(userProfileRepositoryProvider);
    final data = await repo.findByUsername(username);

    setState(() {
      _searching = false;
      if (data == null) {
        _searchError = 'No user found with that username.';
      } else {
        _searchResult = _Suggestion(
          data['uid'] as String,
          data['displayName'] as String? ?? username,
        );
      }
    });
  }

  Future<void> _sendRequest() async {
    final pid = _pidCtl.text.trim();
    if (pid.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _submitting = true;
      _error = null;
      _successPid = null;
    });

    try {
      // Check if printer exists via server
      final checkResponse = await http.get(
        Uri.parse('$_defaultServerUrl/printer-exists?pid=$pid'),
      ).timeout(const Duration(seconds: 5));

      if (checkResponse.statusCode != 200) {
        throw Exception(checkResponse.body);
      }

      final checkData = jsonDecode(checkResponse.body) as Map<String, dynamic>;
      if (checkData['exists'] != true) {
        setState(() {
          _error = 'Printer not found. Check the ID and try again.';
          _submitting = false;
        });
        return;
      }

      // Send permission request
      final response = await http.post(
        Uri.parse('$_defaultServerUrl/send-permission-request?pid=$pid'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'fromUid': uid}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      setState(() {
        _successPid = pid;
        _submitting = false;
        _pidCtl.clear();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to send request. Check the printer ID and try again.';
        _submitting = false;
      });
    }
  }

  void _finish() {
    ref.read(onboardingProvider.notifier).complete();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
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
          'ADD A PRINTER',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.print_outlined, size: 48, color: PrintimateColors.textDim),
              const SizedBox(height: 16),
              Text(
                "ADD A FRIEND'S PRINTER",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your friend's printer ID to send them\na request for access.",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: PrintimateColors.textDim),
              ),
              const SizedBox(height: 32),
              Text('PRINTER ID:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pidCtl,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {
                        _error = null;
                        _successPid = null;
                      }),
                      onSubmitted: (_) => _sendRequest(),
                      decoration: InputDecoration(
                        hintText: 'e.g. pid1',
                        errorText: _error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _submitting ? null : _sendRequest,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('SEND'),
                  ),
                ],
              ),
              if (_successPid != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: PrintimateColors.surface,
                    border: Border.all(color: PrintimateColors.text),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 20, color: PrintimateColors.text),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Request sent to owner of $_successPid',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              OutlinedButton(
                onPressed: _submitting ? null : _finish,
                child: const Text('CONTINUE  →'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _submitting ? null : _finish,
                child: const Text('SKIP FOR NOW'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestion {
  const _Suggestion(this.id, this.name);
  final String id;
  final String name;
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.selected,
    required this.onTap,
  });

  final _Suggestion suggestion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              child: Text(suggestion.name,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            Icon(
              selected ? Icons.check_box_outlined : Icons.check_box_outline_blank,
              color: PrintimateColors.text,
            ),
          ],
        ),
      ),
    );
  }
}