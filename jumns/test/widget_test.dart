import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jems/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: JemsApp()));
    await tester.pumpAndSettle();
    // App should render the welcome screen or chat screen
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
