// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:adilabad_autos_cabs/main.dart';

void main() {
  testWidgets('App builds and shows Login', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
  // Title may appear in multiple places; assert on unique field labels
  expect(find.text('User ID'), findsOneWidget);
  expect(find.text('Password'), findsOneWidget);
  });
}
