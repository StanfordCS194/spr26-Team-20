import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../send/send_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 1});
  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _tabs = ['HISTORY', 'SEND', 'PROFILE'];

  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTabTap(int i) {
    if (i == _index) return;
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScrollConfiguration(
        behavior: const _AnyDeviceScrollBehavior(),
        child: PageView(
          controller: _controller,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (i) => setState(() => _index = i),
          children: const [
            HistoryScreen(),
            SendScreen(),
            ProfileScreen(),
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
