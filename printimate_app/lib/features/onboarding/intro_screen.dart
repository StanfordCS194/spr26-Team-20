import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../services/app_preferences.dart';

class _TourPage {
  const _TourPage({required this.title, required this.body, required this.icon});
  final String title;
  final String body;
  final IconData icon;
}

const _pages = <_TourPage>[
  _TourPage(
    title: 'Send a real letter,\ninstantly.',
    body: 'Printimate turns your messages into\nphysical receipts that print at home.',
    icon: Icons.mail_outline,
  ),
  _TourPage(
    title: 'Pair a printer\nover Bluetooth.',
    body: 'Plug yours in, hold it near your phone,\nand we\'ll do the rest.',
    icon: Icons.bluetooth_searching,
  ),
  _TourPage(
    title: 'Friends and family\ncan write to you.',
    body: 'Approve who can send. Their notes,\nphotos, and doodles print on your unit.',
    icon: Icons.people_outline,
  ),
  _TourPage(
    title: 'Words, photos,\nor drawings.',
    body: 'Anything you can fit on a small slip\nof paper. Real. Tangible. Yours.',
    icon: Icons.brush_outlined,
  ),
];

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(appPreferencesProvider).markIntroTourSeen();
    if (mounted) context.go('/auth');
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: logo + skip
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                children: [
                  SvgPicture.asset('assets/logo.svg', width: 28),
                  const SizedBox(width: 12),
                  Text(
                    'PRINTIMATE',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 3),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'SKIP',
                      style: TextStyle(color: PrintimateColors.textDim, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageView(page: _pages[i], active: i == _index),
              ),
            ),
            // Dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_pages.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: active ? 22 : 6,
                      decoration: BoxDecoration(
                        color: active ? PrintimateColors.text : PrintimateColors.border,
                      ),
                    );
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _next,
                  child: Text(isLast ? 'GET STARTED  →' : 'NEXT  →'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageView extends StatefulWidget {
  const _PageView({required this.page, required this.active});
  final _TourPage page;
  final bool active;

  @override
  State<_PageView> createState() => _PageViewState();
}

class _PageViewState extends State<_PageView> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration: framed icon (placeholder for real art)
          FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: PrintimateColors.border, width: 1),
                  color: PrintimateColors.surface,
                ),
                child: Icon(widget.page.icon, size: 72, color: PrintimateColors.text),
              ),
            ),
          ),
          const SizedBox(height: 48),
          FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: Text(
                widget.page.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      letterSpacing: 1.6,
                      height: 1.25,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: Text(
                widget.page.body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
