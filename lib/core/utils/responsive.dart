import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class Responsive {
  static bool isMobile(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }
    return MediaQuery.sizeOf(context).width < 700;
  }

  static bool isTablet(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return false;
    }
    final width = MediaQuery.sizeOf(context).width;
    return width >= 700 && width < 1024;
  }

  static int gridColumns(BuildContext context) => isMobile(context) ? 2 : 4;

  static double maxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return width < 430 ? width : 430;
    }
    if (width < 700) return width;
    return width < 1180 ? width : 1180;
  }
}
