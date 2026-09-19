class CheckoutOptions {
  const CheckoutOptions({
    required this.keyId,
    required this.amountPaise,
    required this.orderReference,
    required this.description,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
  });

  final String keyId;
  final int amountPaise;
  final String orderReference;
  final String description;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
}
