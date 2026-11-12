import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_quest/main.dart';

void main() {
  testWidgets('signed-out screen offers account controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignIn()));
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Complete challenge'), findsNothing);
  });
}
