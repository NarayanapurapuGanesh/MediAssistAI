import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MediAssistApp());
    expect(find.byType(MediAssistApp), findsOneWidget);
  });
}
