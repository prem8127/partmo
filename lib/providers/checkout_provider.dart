import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/address.dart';
import '../models/payment_method.dart';
import '../core/services/supabase_service.dart';

// ── Addresses ──────────────────────────────────────────────────────────────

final addressesLoadingProvider = StateProvider<bool>((ref) => true);

String _addressIdentity(Address address) => [
      address.label,
      address.name,
      address.line,
      address.city,
      address.phone,
    ].map((value) => value.trim().toLowerCase()).join('|');

/// Combines server and device copies without losing local-only addresses.
/// Put the preferred source first (normally the server) so its database ID is
/// retained when both copies describe the same delivery address.
List<Address> mergeAddressCopies(Iterable<Address> addresses) {
  final merged = <String, Address>{};
  for (final address in addresses) {
    merged.putIfAbsent(_addressIdentity(address), () => address);
  }
  return merged.values.toList();
}

class AddressesNotifier extends StateNotifier<List<Address>> {
  AddressesNotifier({this.onLoadingChanged}) : super(const []) {
    Future.microtask(load);
  }

  final void Function(bool loading)? onLoadingChanged;
  Future<void>? _activeLoad;

  Address _fromRow(Map<String, dynamic> row) => Address(
        id: row['id'] as String,
        label: row['label'] as String? ?? '',
        name: row['name'] as String? ?? '',
        line: row['line'] as String? ?? '',
        city: [row['city'], row['state'], row['pincode']]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join(', '),
        phone: row['phone'] as String? ?? '',
        alternatePhone: row['alternate_phone'] as String? ?? '',
        isDefault: row['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> _toRow(Address address) => {
        'label': address.label,
        'name': address.name,
        'line': address.line,
        'city': address.city,
        'state': '',
        'pincode': '',
        'phone': address.phone,
        'alternate_phone': address.alternatePhone,
        'is_default': address.isDefault,
      };

  String get _storageKey =>
      'partmo_addresses_${SupabaseService.currentUser?.id ?? 'guest'}';

  bool _isLocalId(String id) => id.startsWith('addr');

  Future<List<Address>> _readLocalForKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) =>
              Address.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((address) => address.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Address>> _readLocal() => _readLocalForKey(_storageKey);

  Future<void> _writeLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey,
        jsonEncode(state.map((address) => address.toJson()).toList()));
  }

  Future<Address> _syncNew(Address address) async {
    final saved =
        _fromRow(await SupabaseService.insertAddress(_toRow(address)));
    state = [for (final item in state) item.id == address.id ? saved : item];
    await _writeLocal();
    return saved;
  }

  Future<void> load() {
    if (_activeLoad != null) return _activeLoad!;
    onLoadingChanged?.call(true);
    return _activeLoad = _load().whenComplete(() {
      _activeLoad = null;
      onLoadingChanged?.call(false);
    });
  }

  Future<void> _load() async {
    final local = await _readLocal();
    state = local;
    if (!SupabaseService.isLoggedIn) return;

    // Some older app versions could save an address before the restored auth
    // session was visible, placing it under the guest key. Keep it available
    // for recovery, but only adopt it when this account has no address data.
    final guest = await _readLocalForKey('partmo_addresses_guest');
    try {
      final rows = await SupabaseService.fetchAddresses();
      final remote = rows.map(_fromRow).toList();
      final recovery =
          remote.isEmpty && local.isEmpty ? guest : const <Address>[];

      // Remote rows come first so their database IDs win, while locally saved
      // rows missing from the response remain visible instead of disappearing.
      state = mergeAddressCopies([...remote, ...local, ...recovery]);
      await _writeLocal();

      final remoteIdentities = remote.map(_addressIdentity).toSet();
      final needsSync = state
          .where((address) =>
              !remoteIdentities.contains(_addressIdentity(address)))
          .toList();
      for (final address in needsSync) {
        try {
          await _syncNew(address);
        } catch (_) {
          // Keep the local copy and retry next time the screen opens.
        }
      }
    } catch (_) {
      // Local addresses remain available if Supabase is offline or not
      // migrated. Recover the legacy guest-key copy when it is the only copy.
      if (state.isEmpty && guest.isNotEmpty) {
        state = mergeAddressCopies(guest);
        await _writeLocal();
      }
    }
  }

  Future<Address> addAddress(Address address) async {
    state = [...state, address];
    await _writeLocal();
    if (!SupabaseService.isLoggedIn) return address;
    try {
      return await _syncNew(address);
    } catch (_) {
      return address;
    }
  }

  Future<void> updateAddress(Address updated) async {
    state = [for (final a in state) a.id == updated.id ? updated : a];
    await _writeLocal();
    if (!SupabaseService.isLoggedIn) return;
    try {
      if (_isLocalId(updated.id)) {
        await _syncNew(updated);
      } else {
        await SupabaseService.updateAddress(updated.id, _toRow(updated));
      }
    } catch (_) {
      // The edited local copy remains usable and can sync on a later reload.
    }
  }

  Future<void> removeAddress(String id) async {
    state = state.where((a) => a.id != id).toList();
    await _writeLocal();
    if (!SupabaseService.isLoggedIn || _isLocalId(id)) return;
    try {
      await SupabaseService.deleteAddress(id);
    } catch (_) {
      // Local removal still succeeds if remote sync is unavailable.
    }
  }
}

final addressesProvider =
    StateNotifierProvider<AddressesNotifier, List<Address>>(
  (ref) => AddressesNotifier(
    onLoadingChanged: (loading) =>
        ref.read(addressesLoadingProvider.notifier).state = loading,
  ),
);

// ── Payments ───────────────────────────────────────────────────────────────

class PaymentMethodsNotifier extends StateNotifier<List<PaymentMethod>> {
  PaymentMethodsNotifier()
      : super([
          const PaymentMethod(
              id: 'razorpay',
              title: 'Razorpay Test Checkout',
              subtitle: 'Close Razorpay to confirm with payment pending',
              iconLabel: 'PAY',
              isRecommended: true),
        ]);

  void addMethod(PaymentMethod method) => state = [...state, method];
  void removeMethod(String id) =>
      state = state.where((m) => m.id != id).toList();
}

final paymentMethodsProvider =
    StateNotifierProvider<PaymentMethodsNotifier, List<PaymentMethod>>(
  (ref) => PaymentMethodsNotifier(),
);

// ── Selection ──────────────────────────────────────────────────────────────

class SelectedAddressNotifier extends StateNotifier<String> {
  SelectedAddressNotifier() : super('') {
    load();
  }

  String get _storageKey =>
      'partmo_selected_address_${SupabaseService.currentUser?.id ?? 'guest'}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_storageKey) ?? '';
  }

  Future<void> select(String id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    if (id.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, id);
    }
  }
}

final selectedAddressProvider =
    StateNotifierProvider<SelectedAddressNotifier, String>(
  (ref) => SelectedAddressNotifier(),
);
final selectedPaymentProvider = StateProvider<String>((ref) => 'razorpay');
