import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/invoice_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/order_ref.dart';
import '../../core/utils/order_status.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/whatsapp_launcher.dart';
import '../../providers/whatsapp_order_provider.dart';

class OrderSuccessScreen extends ConsumerStatefulWidget {
  const OrderSuccessScreen({super.key});

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _confettiCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _fadeAnim;

  PendingWhatsAppOrder? _pending;
  late final String _orderRef;
  late final String _estimatedDate;

  static String _getEstimatedDate() {
    final now = DateTime.now();
    final delivery = now.add(const Duration(days: 4));
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

  @override
  void initState() {
    super.initState();

    _pending = ref.read(pendingWhatsAppOrderProvider);
    _orderRef = _pending?.orderRef ?? generateOrderRef();
    _estimatedDate = _pending?.estimatedDelivery ?? estimatedDeliveryDate();

    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));

    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    // Cart is already cleared by CheckoutScreen right before navigating here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _checkCtrl.forward();
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        _fadeCtrl.forward();
        _confettiCtrl.forward();
      });
    });
  }

  String _message() =>
      _pending?.buildMessage() ??
      'PartMo Order Confirmation\nOrder Ref: $_orderRef\nEstimated Delivery: $_estimatedDate';

  Future<void> _notifyAdminOnWhatsApp() async {
    if (!mounted) return;
    await openWhatsAppChat(number: kAdminWhatsAppNumber, message: _message());
  }

  Future<void> _sendCopyToMyWhatsApp() async {
    final number = _pending?.whatsappNumber;
    if (number == null || number.isEmpty) return;
    await openWhatsAppChat(number: number, message: _message());
  }

  Future<void> _sendCopyToAlternateNumber() async {
    final number = _pending?.alternateNumber;
    if (number == null || number.isEmpty) return;
    await openWhatsAppChat(number: number, message: _message());
  }

  Future<void> _downloadInvoice() async {
    final pending = _pending;
    if (pending == null) return;
    final user = SupabaseService.currentUser;
    await InvoiceService.downloadInvoiceImage(InvoiceData(
      orderId: pending.orderRef,
      orderDate: DateTime.now().toIso8601String().split('T').first,
      customerName: user?.userMetadata?['full_name'] as String? ?? 'Customer',
      customerEmail: user?.email ?? '',
      deliveryAddress: pending.address,
      items: [
        for (final item in pending.items)
          InvoiceItem(
            name: item.product.name,
            description: item.product.category,
            qty: item.quantity,
            unitPrice: item.product.price,
          ),
      ],
      deliveryCharge: 0,
      paymentMethod: pending.paymentMethod,
      subtotalAmount: pending.subtotal,
      gstAmountValue: pending.tax,
      grandTotalAmount: pending.total,
    ));
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _fadeCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderSteps = OrderStatus.stepsFor(
      OrderStatus.confirmed,
      placedAt: DateTime.now(),
      eta: _estimatedDate,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          // Confetti layer
          AnimatedBuilder(
            animation: _confettiCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ConfettiPainter(_confettiCtrl.value),
              size: MediaQuery.sizeOf(context),
            ),
          ),
          // Main content
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: Responsive.isMobile(context) ? 390 : 520),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    24, MediaQuery.paddingOf(context).top + 32, 24, 40),
                children: [
                  // Big animated check
                  ScaleTransition(
                    scale: _checkScale,
                    child: Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DBD79),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1DBD79).withOpacity(.35),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 62),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Title
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        Text(
                          'Order Confirmed!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF172635),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          (_pending?.paymentMethod ?? '')
                                  .toLowerCase()
                                  .contains('pending')
                              ? 'Your order was saved successfully.\nPayment is pending.'
                              : 'Your order and Razorpay test payment were confirmed successfully.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF5E6E7C),
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Order detail card
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF172635).withOpacity(.06),
                              blurRadius: 18,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.receipt_long_outlined,
                            label: 'ORDER REFERENCE',
                            value: _orderRef,
                            valueColor: AppPalette.navy,
                          ),
                          const Divider(height: 24, color: Color(0xFFEDF1F6)),
                          _DetailRow(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'PAYMENT METHOD',
                            value:
                                _pending?.paymentMethod ?? 'Payment confirmed',
                            valueColor: const Color(0xFF6B00C9),
                          ),
                          const Divider(height: 24, color: Color(0xFFEDF1F6)),
                          _DetailRow(
                            icon: Icons.local_shipping_outlined,
                            label: 'ESTIMATED DELIVERY',
                            value: _estimatedDate,
                            valueColor: const Color(0xFF1DBD79),
                          ),
                          const Divider(height: 24, color: Color(0xFFEDF1F6)),
                          _DetailRow(
                            icon: Icons.location_on_outlined,
                            label: 'DELIVERING TO',
                            value: _pending?.address ?? 'Address unavailable',
                            valueColor: const Color(0xFF172635),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Status timeline
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF172635).withOpacity(.06),
                              blurRadius: 18,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ORDER STATUS',
                            style: TextStyle(
                                color: Color(0xFF7E8D99),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 18),
                          for (final entry in orderSteps.asMap().entries)
                            _StatusStep(
                              label: entry.value.title,
                              sublabel: entry.value.subtitle,
                              done: entry.value.done,
                              active: entry.value.active,
                              last: entry.key == orderSteps.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // WhatsApp order updates
                  if (_pending != null)
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9FBF1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF1DBD79).withOpacity(.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.chat,
                                    color: Color(0xFF1DBD79), size: 18),
                                SizedBox(width: 8),
                                Text('WHATSAPP UPDATES',
                                    style: TextStyle(
                                        color: Color(0xFF172635),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .8)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use the buttons below to send the order details in WhatsApp.',
                              style: TextStyle(
                                  color: Color(0xFF2E5044),
                                  fontSize: 11,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: FilledButton.icon(
                                onPressed: _notifyAdminOnWhatsApp,
                                icon: const Icon(Icons.send_outlined, size: 16),
                                label: const Text('NOTIFY PARTMO TEAM',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .3)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1DBD79),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _downloadInvoice,
                                icon: const Icon(Icons.receipt_long_outlined,
                                    size: 16),
                                label: const Text('DOWNLOAD / SHARE INVOICE',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _sendCopyToMyWhatsApp,
                                icon: const Icon(Icons.chat_bubble_outline,
                                    size: 16),
                                label: const Text(
                                    'SEND ORDER COPY TO MY WHATSAPP',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .3)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1DBD79),
                                  side: const BorderSide(
                                      color: Color(0xFF1DBD79), width: 1.4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                            if (_pending!.alternateNumber.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: _sendCopyToAlternateNumber,
                                  icon: const Icon(
                                      Icons.phone_forwarded_outlined,
                                      size: 16),
                                  label: const Text(
                                      'SEND COPY TO ALTERNATIVE NUMBER',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // CTA buttons
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: () => context.go('/tracking'),
                            icon: const Icon(Icons.local_shipping_outlined,
                                size: 18),
                            label: const Text('TRACK MY ORDER',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .8)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.navy,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => context.go('/home'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppPalette.navy,
                              side: const BorderSide(
                                  color: AppPalette.navy, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text('CONTINUE SHOPPING',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .6)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Email note
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6EF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF1DBD79).withOpacity(.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.mail_outline,
                              color: Color(0xFF1DBD79), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Download the invoice above and send the order copy through WhatsApp.',
                              style: TextStyle(
                                  color: Color(0xFF2E5044),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail Row ───────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: const Color(0xFF536877), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF9BA8B4),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8)),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      color: valueColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Status step ──────────────────────────────────────────────────────────────
class _StatusStep extends StatelessWidget {
  const _StatusStep({
    required this.label,
    required this.sublabel,
    required this.done,
    required this.active,
    this.last = false,
  });

  final String label;
  final String sublabel;
  final bool done;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final dotColor = done
        ? const Color(0xFF1DBD79)
        : active
            ? AppPalette.cyan
            : const Color(0xFFD4DCE4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : active
                        ? const Icon(Icons.radio_button_checked,
                            color: Colors.white, size: 12)
                        : null,
              ),
              if (!last)
                Container(
                    width: 2,
                    height: 28,
                    color: done
                        ? const Color(0xFF1DBD79).withOpacity(.3)
                        : const Color(0xFFE4EBF2)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 1, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: done || active
                          ? const Color(0xFF172635)
                          : const Color(0xFF9BA8B4),
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
              Text(sublabel,
                  style: TextStyle(
                      color: done
                          ? const Color(0xFF1DBD79)
                          : active
                              ? AppPalette.navy
                              : const Color(0xFFB0BBBF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Confetti painter ─────────────────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);
  final double progress;

  static final _rng = Random(42);
  static final List<_Confetti> _pieces =
      List.generate(60, (i) => _Confetti(_rng));

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    for (final c in _pieces) {
      final x = c.x * size.width;
      final y = (c.startY + progress * c.speed * size.height) % size.height;
      final opacity = (1 - (progress - 0.7).clamp(0, 0.3) / 0.3).clamp(0, 1.0);
      final paint = Paint()..color = c.color.withOpacity(opacity * 0.85);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.rotation + progress * c.rotSpeed);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: c.w, height: c.h),
            const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Confetti {
  _Confetti(Random r)
      : x = r.nextDouble(),
        startY = -r.nextDouble() * 0.5,
        speed = 0.4 + r.nextDouble() * 0.7,
        rotation = r.nextDouble() * 3.14,
        rotSpeed = (r.nextDouble() - 0.5) * 4,
        w = 5 + r.nextDouble() * 6,
        h = 8 + r.nextDouble() * 10,
        color = _colors[r.nextInt(_colors.length)];

  final double x, startY, speed, rotation, rotSpeed, w, h;
  final Color color;

  static const _colors = [
    Color(0xFF00C8C8),
    Color(0xFF073B63),
    Color(0xFF1DBD79),
    Color(0xFFFFC400),
    Color(0xFFFF6B6B),
    Color(0xFF9B59B6),
  ];
}
