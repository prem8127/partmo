import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/supabase_service.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartNotifier extends Notifier<List<CartItem>> {
  StreamSubscription<dynamic>? _authSubscription;
  Future<void>? _activeRestore;
  Future<void> _saveQueue = Future.value();
  late String _activeScope;

  String get _scope {
    try {
      return SupabaseService.currentUser?.id ?? 'guest';
    } catch (_) {
      // Unit tests and offline startup can run before Supabase is initialized.
      return 'guest';
    }
  }

  String _storageKey(String scope) => 'partmo_cart_$scope';

  @override
  List<CartItem> build() {
    _activeScope = _scope;
    Future.microtask(restore);

    try {
      _authSubscription =
          SupabaseService.client.auth.onAuthStateChange.listen((_) async {
        final nextScope = _scope;
        if (nextScope == _activeScope) return;

        // Carry a guest cart into the account on sign-in, but never expose one
        // signed-in user's cart after sign-out or an account switch.
        final carry = _activeScope == 'guest' && nextScope != 'guest'
            ? List<CartItem>.from(state)
            : const <CartItem>[];
        _activeScope = nextScope;
        if (_activeRestore != null) await _activeRestore;
        if (_activeScope == nextScope) {
          state = [];
          await restore(carry: carry);
        }
      });
      ref.onDispose(() => _authSubscription?.cancel());
    } catch (_) {
      // Persistence still works in guest/offline mode.
    }

    return const [];
  }

  List<CartItem> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) =>
              CartItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((item) => item.product.id.isNotEmpty && item.product.stock > 0)
          .map((item) => item.copyWith(
                quantity: item.quantity.clamp(1, item.product.stock).toInt(),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<CartItem> _merge(Iterable<CartItem> items) {
    final merged = <String, CartItem>{};
    for (final item in items) {
      if (item.product.id.isEmpty || item.product.stock <= 0) continue;
      merged[item.product.id] = item.copyWith(
        quantity: item.quantity.clamp(1, item.product.stock).toInt(),
      );
    }
    return merged.values.toList();
  }

  Future<void> restore({List<CartItem> carry = const []}) {
    return _activeRestore ??= _restore(carry).whenComplete(() {
      _activeRestore = null;
    });
  }

  Future<void> _restore(List<CartItem> carry) async {
    try {
      final scope = _activeScope;
      final prefs = await SharedPreferences.getInstance();
      final saved = _decode(prefs.getString(_storageKey(scope)));
      final guest = scope == 'guest'
          ? const <CartItem>[]
          : _decode(prefs.getString(_storageKey('guest')));
      final guestRecovery = saved.isEmpty ? guest : const <CartItem>[];

      // Current in-memory actions come last and therefore win if the user adds
      // an item while restoration is still in progress.
      state = _merge([...saved, ...guestRecovery, ...carry, ...state]);
      await _persistSnapshot(scope, _snapshot());
    } catch (_) {
      // Keep the in-memory cart when browser storage is unavailable.
    }
  }

  Future<void> _persistSnapshot(String scope, String snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(scope), snapshot);
  }

  String _snapshot() => jsonEncode(state.map((item) => item.toJson()).toList());

  Future<void> get persistenceComplete => _saveQueue;

  Future<void> saveNow() {
    _save();
    return persistenceComplete;
  }

  void _save() {
    final scope = _activeScope;
    final snapshot = _snapshot();
    _saveQueue = _saveQueue
        .catchError((_) {})
        .then((_) => _persistSnapshot(scope, snapshot));
    unawaited(_saveQueue.catchError((_) {}));
  }

  bool add(Product product) {
    if (product.stock <= 0) return false;
    final index = state.indexWhere((item) => item.product.id == product.id);
    if (index == -1) {
      state = [...state, CartItem(product: product)];
      _save();
      return true;
    }
    if (state[index].quantity >= product.stock) return false;
    state = [
      for (final item in state)
        if (item.product.id == product.id)
          item.copyWith(product: product, quantity: item.quantity + 1)
        else
          item,
    ];
    _save();
    return true;
  }

  void changeQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      state = state.where((item) => item.product.id != productId).toList();
      _save();
      return;
    }
    state = [
      for (final item in state)
        if (item.product.id == productId)
          item.copyWith(quantity: quantity.clamp(1, item.product.stock).toInt())
        else
          item,
    ];
    _save();
  }

  double get subtotal =>
      state.fold(0, (sum, item) => sum + item.product.price * item.quantity);

  void clear() {
    state = [];
    _save();
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartSubtotalProvider = Provider<double>((ref) {
  return ref
      .watch(cartProvider)
      .fold(0, (sum, item) => sum + item.product.price * item.quantity);
});
