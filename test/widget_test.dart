import 'package:flutter_test/flutter_test.dart';
import 'package:labkeeper/main.dart';

void main() {
  testWidgets('LabKeeper opens the local login screen after splash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LabKeeperApp());

    expect(find.text('LabKeeper'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Welcome to LabKeeper'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('PIN'), findsOneWidget);
  });
}
