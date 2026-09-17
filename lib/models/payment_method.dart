class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconLabel,
    this.isRecommended = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconLabel;
  final bool isRecommended;
}
