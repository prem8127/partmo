import 'package:flutter/services.dart';

class AppLifecycleService {
  static const _channel = MethodChannel('partmo/app_lifecycle');

  static Future<void> moveToBackground() async {
    try {
      await _channel.invokeMethod<void>('moveToBackground');
    } on MissingPluginException {
      // Only Android implements this method. Other platforms keep their
      // normal root-navigation behavior.
    }
  }
}
