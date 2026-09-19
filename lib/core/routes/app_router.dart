import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/supabase_service.dart';
import '../../features/admin/add_product_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_orders_screen.dart';
import '../../features/admin/admin_profile_screen.dart';
import '../../features/admin/analytics_screen.dart';
import '../../features/admin/catalog_management_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_verify_screen.dart'; // ADD THIS
import '../../features/auth/signup_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/checkout/address_selection_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/checkout/order_success_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/orders/order_tracking_screen.dart';
import '../../features/products/product_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/filters_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/wishlist/wishlist_screen.dart';
import '../../providers/whatsapp_order_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;

      if (loc == '/success' && ref.read(pendingWhatsAppOrderProvider) == null) {
        return '/home';
      }

      // Admin route guard
      if (loc.startsWith('/admin')) {
        if (!SupabaseService.isLoggedIn) return '/login';
        if (!SupabaseService.isAdmin) return '/home';
        return null;
      }

      // Checkout/payment route guard — must be logged in
      if (loc == '/checkout' || loc == '/addresses') {
        if (!SupabaseService.isLoggedIn) return '/login?return=$loc';
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        // ADD THIS ROUTE
        path: '/otp-verify',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpVerifyScreen(email: extra?['email'] ?? '');
        },
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: '/catalog',
          builder: (_, state) => CatalogScreen(
              initialCategory: state.uri.queryParameters['category'])),
      GoRoute(
        path: '/search',
        builder: (_, state) =>
            SearchScreen(initialFilters: state.extra as FilterData?),
      ),
      GoRoute(
        path: '/filters',
        builder: (_, state) =>
            FiltersScreen(initial: state.extra as FilterData?),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (_, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(
          path: '/addresses',
          builder: (_, __) => const AddressSelectionScreen()),
      GoRoute(path: '/success', builder: (_, __) => const OrderSuccessScreen()),
      GoRoute(
          path: '/tracking', builder: (_, __) => const OrderTrackingScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/wishlist', builder: (_, __) => const WishlistScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(
          path: '/admin/analytics',
          builder: (_, __) => const AnalyticsScreen()),
      GoRoute(
          path: '/admin/add-product',
          builder: (_, __) => const AddProductScreen()),
      GoRoute(
          path: '/admin/catalog',
          builder: (_, __) => const CatalogManagementScreen()),
      GoRoute(
          path: '/admin/orders', builder: (_, __) => const AdminOrdersScreen()),
      GoRoute(
          path: '/admin/profile',
          builder: (_, __) => const AdminProfileScreen()),
    ],
  );
});
