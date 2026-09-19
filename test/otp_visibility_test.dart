import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/features/auth/otp_verify_screen.dart';

void main() {
  testWidgets('OTP fields render entered digits with a visible text style',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OtpVerifyScreen(email: 'user@example.com')),
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));

    await tester.enterText(fields.first, '7');
    await tester.pump();

    final firstField = tester.widget<TextField>(fields.first);
    expect(firstField.controller?.text, '7');
    expect(firstField.style?.fontSize, 24);
    expect(firstField.style?.color, const Color(0xFF071E33));
    expect(firstField.textAlignVertical, TextAlignVertical.center);
  });
}
