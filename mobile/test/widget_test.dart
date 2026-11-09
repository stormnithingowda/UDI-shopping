import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udi_shopping/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      if (call.method == 'read') return null;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  testWidgets('shows sign-in screen when no saved session exists', (tester) async {
    await tester.pumpWidget(const UdiShoppingApp());
    await tester.pumpAndSettle();

    expect(find.text('UDI Shopping'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
