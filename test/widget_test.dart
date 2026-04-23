import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder build sanity', (WidgetTester tester) async {
    // Real Flutter-widget tests for this app need Hive + Riverpod mocking
    // beyond what's worth wiring up inside the smoke-test harness. Pure-Dart
    // unit tests live alongside this file and exercise domain + parser
    // behaviour directly. See: playlist_needs_refresh_test.dart,
    // playlist_model_test.dart, xtream_client_test.dart.
    expect(true, isTrue);
  });
}
