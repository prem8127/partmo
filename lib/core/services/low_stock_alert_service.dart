import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Sends a low-stock alert email to the admin.
///
/// HOW IT WORKS:
/// Calls a Supabase Edge Function named `send-low-stock-alert`.
/// That Edge Function uses your email provider (Resend / SendGrid / SMTP)
/// to email the admin. See setup instructions in README.
///
/// LOW STOCK THRESHOLD: products with stock <= [lowStockThreshold] are flagged.
class LowStockAlertService {
  static const int lowStockThreshold = 5;
  // Single source of truth for the admin email lives in SupabaseService —
  // kept in sync here so there's only one place to change it.
  static String get adminEmail => SupabaseService.adminEmail;

  static SupabaseClient get _client => Supabase.instance.client;

  /// Call this from admin dashboard or catalog screen.
  /// Returns list of product names that are low on stock.
  static Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    try {
      final response = await _client
          .from('products')
          .select('id, name, stock, category')
          .lte('stock', lowStockThreshold)
          .order('stock', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Sends an email alert to admin listing all low-stock products.
  /// Requires a Supabase Edge Function named `send-low-stock-alert`.
  static Future<LowStockAlertResult> sendAlert() async {
    try {
      final lowProducts = await getLowStockProducts();

      if (lowProducts.isEmpty) {
        return LowStockAlertResult(
          success: true,
          message: 'No low stock items found.',
          productCount: 0,
        );
      }

      // Call the Supabase Edge Function
      final response = await _client.functions.invoke(
        'send-low-stock-alert',
        body: {
          'adminEmail': adminEmail,
          'products': lowProducts,
          'threshold': lowStockThreshold,
          'sentAt': DateTime.now().toIso8601String(),
        },
      );

      if (response.status == 200) {
        return LowStockAlertResult(
          success: true,
          message:
              'Alert sent to $adminEmail for ${lowProducts.length} product(s).',
          productCount: lowProducts.length,
          products: lowProducts,
        );
      } else {
        return LowStockAlertResult(
          success: false,
          message: 'Edge function returned status ${response.status}.',
          productCount: lowProducts.length,
          products: lowProducts,
        );
      }
    } catch (e) {
      return LowStockAlertResult(
        success: false,
        message: 'Failed to send alert: ${e.toString()}',
        productCount: 0,
      );
    }
  }
}

class LowStockAlertResult {
  const LowStockAlertResult({
    required this.success,
    required this.message,
    required this.productCount,
    this.products = const [],
  });
  final bool success;
  final String message;
  final int productCount;
  final List<Map<String, dynamic>> products;
}
