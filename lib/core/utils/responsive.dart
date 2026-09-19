import 'package:flutter/material.dart';

class Responsive {
  // Locked to mobile format everywhere (desktop/web breakpoints disabled).
  static bool isMobile(BuildContext context) => true;
  static bool isTablet(BuildContext context) => false;

  static int gridColumns(BuildContext context) => 2;

  static double maxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Cap at a phone-sized width so wide/desktop browsers still render
    // the mobile layout centered like a phone, instead of stretching it.
    return width < 430 ? width : 430;
  }
}
