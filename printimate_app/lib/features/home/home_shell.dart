import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../friends/incoming_requests.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../send/send_screen.dart';
import '../send/printers_list_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialIndex = 1});
  final int initialIndex;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _tabs = ['HISTORY', 'SEND', 'PROFILE'];

  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  String? _selectedPrinter;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTabTap(int i) {
    if (i == _index) return;
    setState(() => _selectedPrinter = null);
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _showRequestBanner(int count) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: PrintimateColors.surface,
        leading: const Icon(Icons.favorite, color: PrintimateColors.text),
        content: Text(
          count == 1
              ? 'New friend request for your printer!'
              : 'You have $count pending friend requests.',
          style: const TextStyle(color: PrintimateColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              context.push('/friend_requests');
            },
            child: const Text('VIEW'),
          ),
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('DISMISS'),
          ),
        ],
      ),
    );
    // Auto-dismiss so the banner doesn't linger over the demo.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Drop a banner whenever the number of pending requests goes up.
    ref.listen<AsyncValue<List<IncomingRequest>>>(incomingRequestsProvider,
        (prev, next) {
      final prevCount = prev?.asData?.value.length ?? 0;
      final nextCount = next.asData?.value.length ?? 0;
      if (nextCount > prevCount) _showRequestBanner(nextCount);
    });
    final requestCount =
        ref.watch(incomingRequestsProvider).asData?.value.length ?? 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Slim top bar with an "+ add printer" affordance on the right.
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  if (_selectedPrinter != null && _index == 1)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: PrintimateColors.text),
                      onPressed: () => setState(() => _selectedPrinter = null),
                    )
                  else
                    const SizedBox(width: 16),
                  Text(
                    _selectedPrinter != null && _index == 1
                        ? _selectedPrinter!
                        : _tabs[_index],
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      color: PrintimateColors.textDim,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Friend Requests',
                    child: IconButton(
                      icon: requestCount > 0
                          ? Badge.count(
                              count: requestCount,
                              child: const Icon(Icons.favorite,
                                  color: PrintimateColors.text),
                            )
                          : const Icon(Icons.favorite_border,
                              color: PrintimateColors.text),
                      onPressed: () => context.push('/friend_requests'),
                    ),
                  ),
                  // TODO: implement notifications and re-enable this button.
                  // Tooltip(
                  //   message: 'Notifications',
                  //   child: IconButton(
                  //     icon: const Icon(Icons.notifications_outlined, color: PrintimateColors.text),
                  //     onPressed: () => context.push('/notifications'),
                  //   ),
                  // ),
                ],
              ),
            ),
            const Divider(height: 1, color: PrintimateColors.border),
            Expanded(
              child: ScrollConfiguration(
                behavior: const _AnyDeviceScrollBehavior(),
                child: PageView(
                  controller: _controller,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: (i) => setState(() {
                    _index = i;
                    _selectedPrinter = null;
                  }),
                  children: [
                      const HistoryScreen(),
                      _selectedPrinter != null
                          ? SendScreen(printerName: _selectedPrinter!)
                          : PrintersListScreen(
                              onPrinterSelected: (pid) =>
                                  setState(() => _selectedPrinter = pid),
                          ),
                      const ProfileScreen(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: PrintimateColors.background,
            border: Border(top: BorderSide(color: PrintimateColors.border)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _TabButton(
                    label: _tabs[i],
                    selected: i == _index,
                    onTap: () => _onTabTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnyDeviceScrollBehavior extends MaterialScrollBehavior {
  const _AnyDeviceScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.invertedStylus,
      };
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: selected ? PrintimateColors.text : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: TextStyle(
            fontFamily: 'Courier',
            fontFamilyFallback: const ['Menlo', 'monospace'],
            color: selected ? PrintimateColors.text : PrintimateColors.textDim,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}