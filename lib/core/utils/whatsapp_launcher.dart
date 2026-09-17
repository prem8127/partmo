import 'package:url_launcher/url_launcher.dart';

/// The shop/admin's WhatsApp Business number, also used by the existing
/// WhatsApp FAB on the Home screen. Update here if it ever changes.
const String kAdminWhatsAppNumber = '919010907444';

/// Opens a WhatsApp chat pre-filled with [message]. If [number] is null or
/// empty, opens WhatsApp's own compose screen (no fixed recipient).
/// Returns true if WhatsApp (or a WhatsApp-capable handler) was launched.
Future<bool> openWhatsAppChat(
    {required String? number, required String message}) async {
  final cleaned = (number ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  final uri =
      Uri.https('wa.me', cleaned.isEmpty ? '' : '/$cleaned', {'text': message});
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

/// Normalizes a 10-digit Indian mobile number (or one already including a
/// country code) into the '91XXXXXXXXXX' format wa.me expects.
String normalizeIndianWhatsAppNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) return '91$digits';
  return digits;
}
