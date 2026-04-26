import 'package:flutter_test/flutter_test.dart';
import 'package:dresser_app/main.dart';

void main() {
  testWidgets('Dresser app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DresserApp());
    expect(find.byType(DresserApp), findsOneWidget);
  });
}
