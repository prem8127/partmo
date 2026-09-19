import 'product.dart';

class CartItem {
  const CartItem({required this.product, this.quantity = 1});

  final Product product;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: Product.fromJson(
          Map<String, dynamic>.from(json['product'] as Map? ?? const {}),
        ),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );

  CartItem copyWith({Product? product, int? quantity}) {
    return CartItem(
        product: product ?? this.product, quantity: quantity ?? this.quantity);
  }
}
