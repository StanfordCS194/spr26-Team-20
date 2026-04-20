import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:printimate_app/main.dart';

void main() {
  testWidgets('App boots to home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PrintimateApp()));
    await tester.pumpAndSettle();

    expect(find.text('Printimate'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });
}
