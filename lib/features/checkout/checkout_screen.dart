import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/checkout_gateway.dart';
import '../../core/services/checkout_options.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/order_ref.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/whatsapp_launcher.dart';
import '../../core/widgets/web_shell.dart';
import '../../models/address.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/whatsapp_order_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _razorpay = RazorpayGateway();
  final _whatsappCtrl = TextEditingController();
  final _alternatePhoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _placing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        ref.read(addressesProvider.notifier).load(),
        ref.read(selectedAddressProvider.notifier).load(),
      ]);
      if (!mounted) return;
      final addresses = ref.read(addressesProvider);
      final selected = ref.read(selectedAddressProvider);
      if (addresses.isNotEmpty &&
          !addresses.any((address) => address.id == selected)) {
        await ref
            .read(selectedAddressProvider.notifier)
            .select(addresses.first.id);
      }
    });
  }

  @override
  void dispose() {
    _razorpay.dispose();
    _whatsappCtrl.dispose();
    _alternatePhoneCtrl.dispose();
    super.dispose();
  }

  void _placeOrder() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (ref.read(cartProvider).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Your cart is empty. Add a part before checking out.')),
      );
      return;
    }
    if (ref.read(addressesProvider).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add a delivery address before ordering.')),
      );
      return;
    }

    ref.read(pendingWhatsAppOrderProvider.notifier).state = null;
    setState(() => _placing = true);

    final orderRef = generateOrderRef();
    final subtotal = ref.read(cartSubtotalProvider);
    final total = subtotal + (subtotal * .18);
    final user = SupabaseService.currentUser;
    final address = _selectedAddress(ref);
    final phone = normalizeIndianWhatsAppNumber(_whatsappCtrl.text);
    final itemNames = ref
        .read(cartProvider)
        .map((item) => item.product.name)
        .take(3)
        .join(', ');

    _razorpay.open(
      options: CheckoutOptions(
        keyId: RazorpayConfig.keyId,
        amountPaise: (total * 100).round().clamp(100, 100000000).toInt(),
        orderReference: orderRef,
        description: itemNames.isEmpty ? 'PartMo order' : itemNames,
        customerName: address.name,
        customerEmail: user?.email ?? '',
        customerPhone: phone,
      ),
      onSuccess: (paymentId) {
        if (!mounted) return;
        _finalizeOrder(
          paymentMethod: 'Razorpay Test - $paymentId',
          orderRef: orderRef,
        );
      },
      onFailure: (message) {
        if (!mounted) return;
        setState(() => _placing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      onDismiss: () {
        if (!mounted) return;
        _finalizeOrder(
          paymentMethod: 'Razorpay Test - Payment Pending',
          orderRef: orderRef,
        );
      },
    );
  }

  Future<void> _finalizeOrder({
    required String paymentMethod,
    required String orderRef,
  }) async {
    final items = ref.read(cartProvider);
    final subtotal = ref.read(cartSubtotalProvider);
    const shipping = 0.0;
    final tax = subtotal * .18;
    final total = subtotal + shipping + tax;

    final whatsappNumber = normalizeIndianWhatsAppNumber(_whatsappCtrl.text);
    final alternateNumber =
        normalizeIndianWhatsAppNumber(_alternatePhoneCtrl.text);
    final address = _formattedSelectedAddress(ref);
    final eta = estimatedDeliveryDate();

    final itemLines = [
      for (final item in items)
        '${item.product.name} x${item.quantity} - ₹${(item.product.price * item.quantity).toStringAsFixed(0)}',
    ];

    // Best-effort persistence — never blocks checkout if it fails.
    final persistedOrderId = await SupabaseService.createOrder(
      orderRef: orderRef,
      whatsappNumber: whatsappNumber,
      alternateWhatsappNumber: alternateNumber,
      deliveryAddress: address,
      paymentMethod: paymentMethod,
      subtotal: subtotal,
      tax: tax,
      total: total,
      items: [
        for (final item in items)
          {
            'product_name': item.product.name,
            'quantity': item.quantity,
            'unit_price': item.product.price,
          },
      ],
    );

    if (persistedOrderId == null) {
      if (!mounted) return;
      setState(() => _placing = false);
      final detail = SupabaseService.lastOrderSaveError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(
            detail == null || detail.isEmpty
                ? 'The order could not be saved. Your cart was kept; please try again.'
                : 'Order could not be saved: $detail',
          ),
        ),
      );
      return;
    }

    ref.read(pendingWhatsAppOrderProvider.notifier).state =
        PendingWhatsAppOrder(
      orderRef: orderRef,
      whatsappNumber: whatsappNumber,
      alternateNumber: alternateNumber,
      paymentMethod: paymentMethod,
      itemLines: itemLines,
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      address: address,
      estimatedDelivery: eta,
    );

    // The order is already persisted in Supabase (createOrder above) with
    // status 'confirmed'. Refresh the tracking provider so "My Orders" and
    // admin's "Manage Orders" are both reading the same real row — no more
    // hardcoded local-only order state.
    await ref.read(myOrdersProvider.notifier).refresh();

    ref.read(cartProvider.notifier).clear();

    if (!mounted) return;
    setState(() => _placing = false);
    context.go('/success');
  }

  String _formattedSelectedAddress(WidgetRef ref) {
    final address = _selectedAddress(ref);
    return '${address.name}, ${address.line}, ${address.city}';
  }

  Address _selectedAddress(WidgetRef ref) {
    final addresses = ref.read(addressesProvider);
    final selectedId = ref.read(selectedAddressProvider);
    return addresses.firstWhere(
      (a) => a.id == selectedId,
      orElse: () => addresses.isNotEmpty
          ? addresses.first
          : const Address(
              id: '', label: 'Home', name: '', line: '', city: '', phone: ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    const shipping = 0.0;
    final tax = subtotal * .18;
    final total = subtotal + shipping + tax;

    return WebShell(
      selectedIndex: -1,
      backgroundColor: const Color(0xFFF4F7FB),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _GatewayHeader(
                    onBack: () => context.go('/cart'),
                    onCart: () => context.go('/cart')),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DeliveryAddressBlock(),
                      const SizedBox(height: 22),
                      _WhatsAppBlock(
                        controller: _whatsappCtrl,
                        alternateController: _alternatePhoneCtrl,
                      ),
                      const SizedBox(height: 22),
                      const _BlockTitle(
                          icon: Icons.verified_outlined,
                          title: 'ORDER CONFIRMATION'),
                      const SizedBox(height: 12),
                      const _PaymentTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Razorpay Test Checkout',
                        subtitle:
                            'Pay in Razorpay, or close it to confirm this test order with payment pending.',
                        selected: true,
                        onTap: null,
                      ),
                      const SizedBox(height: 22),
                      _OrderSummaryBlock(
                          items: items,
                          subtotal: subtotal,
                          shipping: shipping,
                          tax: tax,
                          total: total),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton(
                          onPressed: _placing ? null : _placeOrder,
                          style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.navy,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4))),
                          child: _placing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4, color: Colors.white))
                              : const Text('PAY WITH RAZORPAY',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'By placing your order, you agree to Precision\nAutomotives\nConditions of Use and Privacy Notice.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF9AA6B1),
                            fontSize: 8.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WhatsAppBlock extends StatelessWidget {
  const _WhatsAppBlock(
      {required this.controller, required this.alternateController});
  final TextEditingController controller;
  final TextEditingController alternateController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat, color: Color(0xFF1DBD79), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('WHATSAPP NUMBER FOR ORDER UPDATES',
                    style: TextStyle(
                        color: Color(0xFF172635),
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "We'll send your delivery details to this number on WhatsApp.",
            style: TextStyle(
                color: Color(0xFF6F7F8D),
                fontSize: 10.5,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF172635)),
            decoration: InputDecoration(
              counterText: '',
              prefixText: '+91  ',
              prefixStyle: const TextStyle(
                  color: Color(0xFF172635),
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
              hintText: '10-digit WhatsApp number',
              filled: true,
              fillColor: const Color(0xFFF4F7FB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.length != 10)
                return 'Enter a valid 10-digit WhatsApp number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: alternateController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              counterText: '',
              prefixText: '+91  ',
              hintText: 'Alternative mobile number (optional)',
              filled: true,
              fillColor: Color(0xFFF4F7FB),
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.isNotEmpty && digits.length != 10) {
                return 'Enter a valid 10-digit alternative number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _GatewayHeader extends StatelessWidget {
  const _GatewayHeader({required this.onBack, required this.onCart});

  final VoidCallback onBack;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          10, MediaQuery.paddingOf(context).top + 10, 10, 10),
      child: Row(
        children: [
          IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back,
                  color: AppPalette.navy, size: 19),
              visualDensity: VisualDensity.compact),
          const Text('Checkout',
              style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(
              onPressed: onCart,
              icon: const Icon(Icons.shopping_cart_outlined,
                  color: AppPalette.navy, size: 20),
              visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}

class _DeliveryAddressBlock extends ConsumerWidget {
  const _DeliveryAddressBlock();

  void _editMobile(BuildContext context, WidgetRef ref, Address address) {
    final phoneCtrl = TextEditingController(text: address.phone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit mobile number',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '10-digit mobile number',
              counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.length != 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter exactly 10 digits.')));
                return;
              }
              await ref.read(addressesProvider.notifier).updateAddress(
                    Address(
                      id: address.id,
                      label: address.label,
                      name: address.name,
                      line: address.line,
                      city: address.city,
                      phone: phone,
                      alternatePhone: address.alternatePhone,
                      isDefault: address.isDefault,
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    final selectedId = ref.watch(selectedAddressProvider);
    final address = addresses.firstWhere(
      (a) => a.id == selectedId,
      orElse: () => addresses.isNotEmpty
          ? addresses.first
          : const Address(
              id: '',
              label: 'Home',
              name: 'No address saved',
              line: 'Add a delivery address to continue',
              city: '',
              phone: ''),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppPalette.navy, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('DELIVERY ADDRESS',
                      style: TextStyle(
                          color: Color(0xFF172635),
                          fontSize: 12,
                          fontWeight: FontWeight.w900))),
              TextButton(
                onPressed: () => context.push('/addresses'),
                child: const Text('Add / Change',
                    style:
                        TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(address.name.isEmpty ? '—' : address.name,
              style: const TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 12,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
            [address.line, address.city].where((s) => s.isNotEmpty).join('\n'),
            style: const TextStyle(
                color: Color(0xFF536372),
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(address.phone.isEmpty ? 'No phone on file' : address.phone,
                  style: const TextStyle(
                      color: Color(0xFF172635),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              if (address.id.isNotEmpty)
                InkWell(
                  onTap: () => _editMobile(context, ref, address),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Icon(Icons.edit_outlined,
                        size: 14, color: AppPalette.cyan),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppPalette.navy, size: 17),
        const SizedBox(width: 7),
        Text(title,
            style: const TextStyle(
                color: Color(0xFF172635),
                fontSize: 12,
                fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.selected,
      required this.onTap,
      this.iconColor});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(4)),
        child: Row(
          children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: const Color(0xFFE6EDF4),
                    borderRadius: BorderRadius.circular(2)),
                child:
                    Icon(icon, color: iconColor ?? AppPalette.navy, size: 20)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFF172635),
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6F7F8D),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppPalette.navy : const Color(0xFFB6C0CA),
                size: 22),
          ],
        ),
      ),
    );
  }
}

class _OrderSummaryBlock extends StatelessWidget {
  const _OrderSummaryBlock(
      {required this.items,
      required this.subtotal,
      required this.shipping,
      required this.tax,
      required this.total});

  final List<dynamic> items;
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle(icon: Icons.receipt_long, title: 'ORDER SUMMARY'),
          const SizedBox(height: 16),
          for (final item in items) _SummaryProduct(item: item),
          const Divider(height: 22, color: Color(0xFFE3EAF0)),
          _SummaryLine(label: 'Subtotal', value: subtotal),
          const _SummaryLine(
              label: 'Shipping & Handling', value: 0, free: true),
          _SummaryLine(label: 'Tax (GST 18%)', value: tax),
          const SizedBox(height: 12),
          const Text('TOTAL AMOUNT',
              style: TextStyle(
                  color: Color(0xFF5F6F7D),
                  fontSize: 9,
                  fontWeight: FontWeight.w900)),
          Row(
            children: [
              Text('₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppPalette.navy,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFD9F6FF),
                    borderRadius: BorderRadius.circular(9)),
                child: const Text('SAVED ₹459',
                    style: TextStyle(
                        color: AppPalette.navy,
                        fontSize: 8,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryProduct extends StatelessWidget {
  const _SummaryProduct({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              width: 48,
              height: 48,
              color: const Color(0xFFE7ECF2),
              child: _hasRealImage(item.product.imageIcon)
                  ? Image.network(
                      item.product.imageIcon,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const SizedBox(),
                      errorBuilder: (_, __, ___) => Icon(
                          _partIcon(item.product.imageIcon),
                          color: const Color(0xFF536877),
                          size: 26),
                    )
                  : Icon(_partIcon(item.product.imageIcon),
                      color: const Color(0xFF536877), size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${item.product.category.toString().toUpperCase()}\n${item.product.name}\nQTY: ${item.quantity}',
              style: const TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 10.2,
                  height: 1.25,
                  fontWeight: FontWeight.w800),
            ),
          ),
          Text('₹${item.product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 12,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(
      {required this.label, required this.value, this.free = false});

  final String label;
  final double value;
  final bool free;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Color(0xFF5E6E7C),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700))),
          Text(free ? 'FREE' : '₹${value.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

bool _hasRealImage(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

IconData _partIcon(String key) {
  return switch (key) {
    'engine' => Icons.precision_manufacturing,
    'brake' => Icons.disc_full,
    'air' => Icons.blur_on,
    'oil' => Icons.filter_alt,
    'link' => Icons.timeline,
    _ => Icons.filter_alt,
  };
}
