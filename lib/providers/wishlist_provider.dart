import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/supabase_service.dart';

class WishlistNotifier extends StateNotifier<Set<String>> {
  WishlistNotifier() : super({});

  String get _userKey {
    try {
      return SupabaseService.currentUser?.id ?? 'guest';
    } catch (_) {
      return 'guest';
    }
  }

  String get _savedKey => 'partmo_wishlist_$_userKey';
  String get _removedKey => 'partmo_wishlist_removed_$_userKey';

  Future<void> _persistState(SharedPreferences prefs) async {
    final ids = state.toList()..sort();
    await prefs.setStringList(_savedKey, ids);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final localIds = prefs.getStringList(_savedKey)?.toSet() ?? <String>{};
    final removedIds = prefs.getStringList(_removedKey)?.toSet() ?? <String>{};
    state = {...localIds}..removeAll(removedIds);

    try {
      final remoteIds = (await SupabaseService.fetchWishlistIds()).toSet();
      final latestLocal = prefs.getStringList(_savedKey)?.toSet() ?? <String>{};
      final latestRemoved =
          prefs.getStringList(_removedKey)?.toSet() ?? <String>{};
      state = {...remoteIds, ...latestLocal}..removeAll(latestRemoved);
      await _persistState(prefs);
    } catch (_) {}
  }

  Future<void> toggle(String productId) async {
    final removing = state.contains(productId);
    state = removing ? ({...state}..remove(productId)) : {...state, productId};

    final prefs = await SharedPreferences.getInstance();
    final removedIds = prefs.getStringList(_removedKey)?.toSet() ?? <String>{};
    if (removing) {
      removedIds.add(productId);
    } else {
      removedIds.remove(productId);
    }
    await _persistState(prefs);
    await prefs.setStringList(_removedKey, removedIds.toList()..sort());

    try {
      if (removing) {
        await SupabaseService.removeFromWishlist(productId);
        removedIds.remove(productId);
        await prefs.setStringList(_removedKey, removedIds.toList()..sort());
      } else {
        await SupabaseService.addToWishlist(productId);
      }
    } catch (_) {
      // Keep the local saved state responsive even if remote wishlist sync is
      // blocked by network/RLS. The next successful load will reconcile it.
    }
  }

  bool isWishlisted(String productId) => state.contains(productId);
}

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, Set<String>>((ref) {
  final notifier = WishlistNotifier();
  if (SupabaseService.isLoggedIn) notifier.load();
  return notifier;
});
