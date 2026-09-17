import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:precision_parts_frontend/main.dart';

void main() {
  testWidgets('app starts on splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PrecisionPartsApp()));

    expect(find.text('PARTMO'), findsOneWidget);
  });
}
