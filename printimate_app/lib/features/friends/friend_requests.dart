// friend_requests.dart - Screen for managing incoming friend requests.
//
// The list is driven by [incomingRequestsProvider], a realtime Firestore
// stream, so requests appear and disappear live (including when accepted or
// rejected from another device) without any manual refresh.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../app/api.dart';
import '../../app/config.dart';
import '../../app/theme.dart';
import 'incoming_requests.dart';

class _FriendRequest {
  final String username;
  final String uid;
  final String printerName;
  const _FriendRequest({
    required this.username,
    required this.uid,
    required this.printerName,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() =>
      _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  /// Cache of requesterUid -> display username, so we resolve each name once.
  final Map<String, String> _usernameCache = {};

  /// In-flight accept/decline keys ("pid|uid") to avoid double-taps.
  final Set<String> _processing = {};

  String _key(IncomingRequest r) => '${r.pid}|${r.requesterUid}';

  /// Lazily resolve any usernames we haven't seen yet.
  void _ensureUsernames(List<IncomingRequest> requests) {
    for (final r in requests) {
      if (_usernameCache.containsKey(r.requesterUid)) continue;
      _usernameCache[r.requesterUid] = ''; // mark in-flight to avoid refetch
      fetchUsername(r.requesterUid).then((name) {
        if (!mounted) return;
        setState(() => _usernameCache[r.requesterUid] = name);
      });
    }
  }

  Future<void> _respond(IncomingRequest request, {required bool accept}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final key = _key(request);
    if (_processing.contains(key)) return;
    setState(() => _processing.add(key));

    final endpoint =
        accept ? 'accept-permission-request' : 'reject-permission-request';
    try {
      final res = await http.post(
        Uri.parse('${Config.serverBaseUrl}/$endpoint'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ownersUid': currentUser.uid,
          'pid': request.pid,
          'requestersUid': request.requesterUid,
        }),
      );

      if (!mounted) return;
      final ok = res.statusCode == 200;
      // The realtime stream removes the row on success; just surface a toast.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? (accept ? 'Request accepted!' : 'Request rejected!')
              : 'Failed to ${accept ? 'accept' : 'decline'} request'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(incomingRequestsProvider);
    final requests = requestsAsync.asData?.value ?? const <IncomingRequest>[];
    _ensureUsernames(requests);

    return Scaffold(
      backgroundColor: PrintimateColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: PrintimateColors.text),
                    onPressed: () => context.pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.person_add_outlined, color: PrintimateColors.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'FRIEND REQUESTS',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  if (requests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: PrintimateColors.border),
                      ),
                      child: Text(
                        '${requests.length}',
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                          color: PrintimateColors.textDim,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(color: PrintimateColors.border, height: 1),

            // ── Sub-header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 14, color: PrintimateColors.textDim),
                  const SizedBox(width: 8),
                  Text(
                    'People who want to send messages to your printer',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: PrintimateColors.textDim,
                        ),
                  ),
                ],
              ),
            ),

            const Divider(color: PrintimateColors.border, height: 1),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: requestsAsync.isLoading && requests.isEmpty
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
                  : requests.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          itemCount: requests.length,
                          separatorBuilder: (_, _) => const Divider(
                              color: PrintimateColors.border, height: 1),
                          itemBuilder: (context, index) {
                            final r = requests[index];
                            final cached = _usernameCache[r.requesterUid];
                            final username = (cached == null || cached.isEmpty)
                                ? 'Someone'
                                : cached;
                            return _RequestTile(
                              request: _FriendRequest(
                                username: username,
                                uid: r.requesterUid,
                                printerName: r.pid,
                              ),
                              busy: _processing.contains(_key(r)),
                              onAccept: () => _respond(r, accept: true),
                              onDecline: () => _respond(r, accept: false),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Request tile
// ---------------------------------------------------------------------------

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  final _FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.person_outline,
              size: 20, color: PrintimateColors.textDim),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
                children: [
                  TextSpan(text: request.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' is requesting access to your printer '),
                  TextSpan(text: request.printerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(6),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: PrintimateColors.text),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 16),
                // Accept
                Tooltip(
                  message: 'Accept',
                  child: InkWell(
                    onTap: onAccept,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.check,
                          size: 18, color: PrintimateColors.text),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Decline
                Tooltip(
                  message: 'Decline',
                  child: InkWell(
                    onTap: onDecline,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close,
                          size: 18, color: PrintimateColors.textDim),
                    ),
                  ),
                ),
              ],
            ),
        ],
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
          const Icon(Icons.person_off_outlined,
              size: 36, color: PrintimateColors.textDim),
          const SizedBox(height: 16),
          Text(
            'NO PENDING REQUESTS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: PrintimateColors.textDim,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Friend requests will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PrintimateColors.textDim,
                ),
          ),
        ],
      ),
    );
  }
}
