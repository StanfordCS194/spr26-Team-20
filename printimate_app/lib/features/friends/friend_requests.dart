// friend_requests.dart - Screen for managing incoming friend requests

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app/config.dart';
import '../../app/api.dart';
// ---------------------------------------------------------------------------
// Mock data
// ---------------------------------------------------------------------------

class _FriendRequest {
  final String username;
  final String uid;
  final String printer_name;
  const _FriendRequest({
    required this.username,
    required this.uid,
    required this.printer_name,
  });
}

// If don't have friends, activate this mock data to show what the screen looks like 
//const _friendRequests = [
//   _FriendRequest(username: 'Sarah Chen', printer_name: 'john-printer1'),
//   _FriendRequest(username: 'Mike Thompson', printer_name: 'john-printer1'),
//   _FriendRequest(username: 'Emily Rodriguez', printer_name: 'john-printer2'),
//   _FriendRequest(username: 'Jordan Lee', printer_name: 'john-printer3'),
//   _FriendRequest(username: 'Alex Kim', printer_name: 'john-printer3'),
// ];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final List<_FriendRequest> _requests = [];

  Future<void> _accept(int index) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final request = _requests[index];
    final res = await http.post(
      Uri.parse('${Config.serverBaseUrl}/accept-permission-request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'ownersUid': currentUser.uid,
        'pid': request.printer_name,
        'requestersUid': request.uid,
      }),
    );

    if (res.statusCode == 200) {
      setState(() => _requests.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept request')),
      );
    }
  }

  Future<void> _decline(int index) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final request = _requests[index];
    final res = await http.post(
      Uri.parse('${Config.serverBaseUrl}/reject-permission-request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'ownersUid': currentUser.uid,
        'pid': request.printer_name,
        'requestersUid': request.uid,
      }),
    );

    if (res.statusCode == 200) {
      setState(() => _requests.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to decline request')),
      );
    }
  }
  @override
  void initState() {
    super.initState();
    _loadFriendRequests();
  }
  Future<void> _loadFriendRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final results = await fetchFriendRequests(currentUser.uid);

    final List<_FriendRequest> loaded = [];
    for (final entry in results) {
      final requesterUid = entry['requesterUid'] as String;
      final username = await fetchUsername(requesterUid);
      loaded.add(_FriendRequest(
        username: username,
        uid: requesterUid,
        printer_name: entry['pid'] as String,
      ));
    }

    setState(() {
      _requests.clear();
      _requests.addAll(loaded);
    });
  }
  @override
  Widget build(BuildContext context) {
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
                  if (_requests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: PrintimateColors.border),
                      ),
                      child: Text(
                        '${_requests.length}',
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
              child: _requests.isEmpty
                  ? _EmptyState()
                  : ListView.separated(
                      itemCount: _requests.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: PrintimateColors.border, height: 1),
                      itemBuilder: (context, index) => _RequestTile(
                        request: _requests[index],
                        onAccept: () => _accept(index),
                        onDecline: () => _decline(index),
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
// Request tile
// ---------------------------------------------------------------------------

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final _FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
                  TextSpan(text: request.printer_name, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
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