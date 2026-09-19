import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../models/order.dart';
import '../core/services/supabase_service.dart';
import 'orders_provider.dart';
export 'garage_provider.dart';

// ── Navigation ─────────────────────────────────────────────────────────────
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// ── User ──────────────────────────────────────────────────────────────────
class UserNotifier extends StateNotifier<UserProfile> {
  UserNotifier()
      : super(UserProfile(
          name: SupabaseService.currentUser?.userMetadata?['full_name']
                  as String? ??
              'Guest',
          role: 'Member',
          vehicle: '',
          memberSince: DateTime.now().year.toString(),
          email: SupabaseService.currentUser?.email,
        ));

  Future<void> loadProfile() async {
    final data = await SupabaseService.fetchProfile();
    if (data == null) return;
    state = state.copyWith(
      name: data['full_name'] as String? ?? state.name,
      phone: data['phone'] as String?,
      photoUrl: data['avatar_url'] as String?,
    );
  }

  void updateProfile({String? name, String? role, String? phone}) {
    state = state.copyWith(name: name, role: role, phone: phone);
    SupabaseService.upsertProfile({
      if (name != null) 'full_name': name,
      if (phone != null) 'phone': phone,
    }).catchError((_) {});
  }

  void setPhoto(Uint8List bytes) => state = state.copyWith(photoBytes: bytes);
  void setPhotoUrl(String url) => state = state.copyWith(photoUrl: url);
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile>((ref) {
  final notifier = UserNotifier();
  if (SupabaseService.isLoggedIn) notifier.loadProfile();
  return notifier;
});

final activeOrderProvider = Provider<Order?>((ref) {
  final orders = ref.watch(myOrdersProvider).valueOrNull ?? const [];
  if (orders.isEmpty) return null;
  return orders.first;
});
