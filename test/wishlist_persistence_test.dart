import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/providers/wishlist_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('favorited products remain saved after provider reload', () async {
    SharedPreferences.setMockInitialValues({});

    final first = WishlistNotifier();
    await first.toggle('product-1');
    expect(first.state, contains('product-1'));

    final reloaded = WishlistNotifier();
    await reloaded.load();
    expect(reloaded.state, contains('product-1'));
  });

  test('removed favorites stay removed after provider reload', () async {
    SharedPreferences.setMockInitialValues({
      'partmo_wishlist_guest': ['product-1'],
    });

    final first = WishlistNotifier();
    await first.load();
    await first.toggle('product-1');
    expect(first.state, isNot(contains('product-1')));

    final reloaded = WishlistNotifier();
    await reloaded.load();
    expect(reloaded.state, isNot(contains('product-1')));
  });
}
