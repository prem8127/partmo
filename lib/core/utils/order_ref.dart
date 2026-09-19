import 'dart:math';

String generateOrderRef() {
  final suffix =
      String.fromCharCodes(List.generate(2, (_) => 65 + Random().nextInt(26)));
  return '#PP-${10000 + Random().nextInt(89999)}-$suffix';
}

String estimatedDeliveryDate({int daysFromNow = 4}) {
  final now = DateTime.now();
  final delivery = now.add(Duration(days: daysFromNow));
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${delivery.day} ${months[delivery.month - 1]} ${delivery.year}';
}
