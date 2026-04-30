import 'package:flutter/material.dart';

import '../../app/theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('HISTORY', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Divider(color: PrintimateColors.border, height: 1),
            const Expanded(
              child: Center(
                child: Text(
                  'NOTHING HERE YET',
                  style: TextStyle(
                    color: PrintimateColors.textDim,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
