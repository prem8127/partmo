import 'package:flutter/material.dart';

class AppConstants {
  static const appName = 'PartMo';
  static const tagline = 'Certified spares delivered fast';
  static const supportPhone = '+91 98765 43210';
  static const currency = '₹';
}

class RazorpayConfig {
  // Razorpay Key IDs are public client identifiers. The Key Secret must stay
  // on a server and is intentionally never included in this Flutter app.
  static const keyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_TECslueb7p0Gwc',
  );
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppPalette {
  static const navy = Color(0xFF073B63);
  static const ink = Color(0xFF102333);
  static const muted = Color(0xFF66788A);
  static const line = Color(0xFFE4ECF2);
  static const surface = Color(0xFFF6FAFD);
  static const cyan = Color(0xFF18B8E8);
  static const warning = Color(0xFFFFC233);
  static const success = Color(0xFF2FB36D);
  static const danger = Color(0xFFE85050);
}

const kVehicleTypes = <String>[
  'Sedan',
  'SUV / MUV',
  'Hatchback',
  'Pickup Truck',
  'Van / Minivan',
  'Motorcycle',
  'Auto Rickshaw',
  'Commercial Vehicle',
  'Tractor / Farm',
  'Other',
];
