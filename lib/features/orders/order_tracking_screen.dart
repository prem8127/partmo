import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/invoice_service.dart' as invoice;
import '../../core/utils/responsive.dart';
import '../../core/utils/whatsapp_launcher.dart';
import '../../core/widgets/web_shell.dart';
import '../../providers/orders_provider.dart';
import '../../models/order.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);
    final orders = ordersAsync.valueOrNull ?? const [];
    final latestOrder = orders.isEmpty ? null : orders.first;

    return WebShell(
      selectedIndex: 3,
      backgroundColor: const Color(0xFFF4F7FB),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                    14, MediaQuery.paddingOf(context).top + 12, 14, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.arrow_back,
                          color: AppPalette.navy, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    const Text('My Orders',
                        style: TextStyle(
                            color: AppPalette.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          ref.read(myOrdersProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh,
                          color: AppPalette.navy, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Refresh status',
                    ),
                    if (orders.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            _downloadInvoice(context, latestOrder!),
                        child: const Row(children: [
                          Icon(Icons.download_outlined,
                              size: 16, color: AppPalette.navy),
                          SizedBox(width: 4),
                          Text('Invoice',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppPalette.navy)),
                        ]),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(myOrdersProvider.notifier).refresh(),
                  child: ordersAsync.isLoading && orders.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : orders.isEmpty
                          ? _EmptyOrders(onShop: () => context.go('/catalog'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(18),
                              itemCount: orders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (_, i) => _OrderCard(
                                order: orders[i],
                                onDownload: () =>
                                    _downloadInvoice(context, orders[i]),
                                onWhatsApp: () => _shareOnWhatsApp(orders[i]),
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadInvoice(BuildContext context, Order order) async {
    try {
      final userName =
          SupabaseService.currentUser?.userMetadata?['full_name'] ??
              SupabaseService.currentUser?.email?.split('@').first ??
              'Customer';
      final userEmail = SupabaseService.currentUser?.email ?? '';
      await invoice.InvoiceService.downloadInvoice(invoice.InvoiceData(
        orderId: order.id,
        orderDate: order.placedAt != null
            ? '${order.placedAt!.day}/${order.placedAt!.month}/${order.placedAt!.year}'
            : DateTime.now().toString().substring(0, 10),
        customerName: userName,
        customerEmail: userEmail,
        deliveryAddress:
            order.address.isEmpty ? 'Address unavailable' : order.address,
        paymentMethod: order.paymentMethod.isEmpty
            ? 'Online Payment'
            : order.paymentMethod,
        deliveryCharge: 0,
        subtotalAmount: order.subtotal > 0 ? order.subtotal : order.amount,
        gstAmountValue: order.tax,
        grandTotalAmount: order.amount,
        items: order.lines.isEmpty
            ? [
                invoice.InvoiceItem(
                    name: 'Automotive Spare Part',
                    description: order.items.join(', '),
                    qty: 1,
                    unitPrice:
                        order.subtotal > 0 ? order.subtotal : order.amount)
              ]
            : order.lines
                .map((line) => invoice.InvoiceItem(
                    name: line.name,
                    description: 'Automotive spare part',
                    qty: line.quantity,
                    unitPrice: line.unitPrice))
                .toList(),
      ));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Invoice error: $e')));
    }
  }

  Future<void> _shareOnWhatsApp(Order order) async {
    final itemsBlock = order.items.isEmpty
        ? '• Automotive Spare Part'
        : order.items.map((n) => '• $n').join('\n');
    final message = 'PartMo Order Update\n'
        'Order Ref: ${order.id}\n\n'
        'Items:\n$itemsBlock\n\n'
        'Status: ${order.statusLabel}\n'
        '${order.courierName.isNotEmpty ? 'Delivery Partner: ${order.courierName}\n' : ''}'
        '${order.trackingNumber.isNotEmpty ? 'Tracking ID: ${order.trackingNumber}\n' : ''}'
        '${order.statusNote.isNotEmpty ? 'Update: ${order.statusNote}\n' : ''}'
        'Total: ₹${order.amount.toStringAsFixed(0)}\n'
        'Estimated Delivery: ${order.eta}\n'
        '${order.address.isNotEmpty ? 'Delivering to: ${order.address}\n' : ''}';
    await openWhatsAppChat(number: order.whatsappNumber, message: message);
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.onShop});
  final VoidCallback onShop;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text('No orders yet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172635))),
            const SizedBox(height: 10),
            const Text('Place your first order and track it right here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF7D8B97), fontSize: 13, height: 1.5)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onShop,
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Start Shopping',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5))),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(
      {required this.order,
      required this.onDownload,
      required this.onWhatsApp});
  final Order order;
  final VoidCallback onDownload;
  final VoidCallback onWhatsApp;
  @override
  Widget build(BuildContext context) {
    final doneCount = order.steps.where((s) => s.done).length;
    final progress = doneCount / order.steps.length;
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(7)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
            decoration: const BoxDecoration(
                color: AppPalette.navy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(7))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.id,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                            order.placedAt != null
                                ? 'Placed ${order.placedAt!.day}/${order.placedAt!.month}/${order.placedAt!.year}'
                                : 'Recently placed',
                            style: const TextStyle(
                                color: Color(0xFF9BBACE), fontSize: 10)),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppPalette.cyan,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(order.statusLabel,
                      style: const TextStyle(
                          color: AppPalette.navy,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE4EBF1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.cyan),
              minHeight: 3),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < order.steps.length; i++)
                  _StepRow(
                      step: order.steps[i],
                      isLast: i == order.steps.length - 1),
                if (order.statusNote.isNotEmpty ||
                    order.courierName.isNotEmpty ||
                    order.trackingNumber.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F6FA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DELIVERY UPDATE',
                            style: TextStyle(
                                color: AppPalette.navy,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7)),
                        if (order.statusNote.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(order.statusNote,
                              style: const TextStyle(
                                  color: Color(0xFF526474),
                                  fontSize: 11,
                                  height: 1.4)),
                        ],
                        if (order.courierName.isNotEmpty ||
                            order.trackingNumber.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            [
                              if (order.courierName.isNotEmpty)
                                order.courierName,
                              if (order.trackingNumber.isNotEmpty)
                                'AWB ${order.trackingNumber}',
                            ].join(' • '),
                            style: const TextStyle(
                                color: AppPalette.navy,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(color: Color(0xFFE4EBF1)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('ORDER TOTAL',
                              style: TextStyle(
                                  color: Color(0xFF7E8D99),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8)),
                          const SizedBox(height: 4),
                          Text('₹${order.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: AppPalette.navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                        ])),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('ESTIMATED DELIVERY',
                              style: TextStyle(
                                  color: Color(0xFF7E8D99),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8)),
                          const SizedBox(height: 4),
                          Text(order.eta,
                              style: const TextStyle(
                                  color: Color(0xFF172635),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900)),
                        ])),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.picture_as_pdf_outlined,
                        size: 16, color: AppPalette.navy),
                    label: const Text('Download Invoice',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppPalette.navy)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppPalette.navy),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5))),
                  ),
                ),
                if (order.whatsappNumber.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: onWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline,
                          size: 16, color: Color(0xFF1DBD79)),
                      label: const Text('Share via WhatsApp',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1DBD79))),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1DBD79)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5))),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});
  final OrderStep step;
  final bool isLast;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: step.done
                  ? AppPalette.navy
                  : (step.active ? AppPalette.cyan : const Color(0xFFE4EBF1)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.done
                  ? Icons.check
                  : (step.active
                      ? Icons.radio_button_checked
                      : Icons.circle_outlined),
              color: step.done || step.active
                  ? Colors.white
                  : const Color(0xFFBCCAD5),
              size: 12,
            ),
          ),
          if (!isLast)
            Container(width: 2, height: 28, color: const Color(0xFFE4EBF1)),
        ]),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.title,
                style: TextStyle(
                    color: step.done || step.active
                        ? const Color(0xFF172635)
                        : const Color(0xFF9BAAB6),
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 1),
            Text(step.subtitle,
                style: TextStyle(
                    color:
                        step.active ? AppPalette.navy : const Color(0xFF7D8B97),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    );
  }
}

class InvoiceItem {
  const InvoiceItem(
      {required this.name,
      required this.description,
      required this.qty,
      required this.unitPrice});
  final String name;
  final String description;
  final int qty;
  final double unitPrice;
  double get total => qty * unitPrice;
}

class InvoiceData {
  const InvoiceData(
      {required this.orderId,
      required this.orderDate,
      required this.customerName,
      required this.customerEmail,
      required this.deliveryAddress,
      required this.items,
      required this.deliveryCharge,
      required this.paymentMethod,
      this.gstPercent = 18.0});
  final String orderId,
      orderDate,
      customerName,
      customerEmail,
      deliveryAddress,
      paymentMethod;
  final List<InvoiceItem> items;
  final double deliveryCharge, gstPercent;
  double get subtotal => items.fold(0, (sum, i) => sum + i.total);
  double get gstAmount => subtotal * gstPercent / 100;
  double get grandTotal => subtotal + gstAmount + deliveryCharge;
}

class InvoiceService {
  static Future<void> downloadInvoice(InvoiceData data) async {
    final pdf = pw.Document();
    const navy = PdfColor.fromInt(0xFF073B63);
    const cyan = PdfColor.fromInt(0xFF00B4D8);
    const lightBg = PdfColor.fromInt(0xFFF4F7FB);
    const textDark = PdfColor.fromInt(0xFF172635);
    const textMid = PdfColor.fromInt(0xFF4E6070);
    const divider = PdfColor.fromInt(0xFFDCE5ED);
    const whiteFixed = PdfColors.white;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
              color: navy, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PARTMO',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('Genuine Automotive Spare Parts',
                        style: pw.TextStyle(color: cyan, fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text('www.partmo.in  |  support@partmo.in',
                        style: pw.TextStyle(color: whiteFixed, fontSize: 8)),
                  ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('TAX INVOICE',
                        style: pw.TextStyle(
                            color: cyan,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 2)),
                    pw.SizedBox(height: 4),
                    pw.Text(data.orderId,
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Date: ${data.orderDate}',
                        style: pw.TextStyle(color: whiteFixed, fontSize: 9)),
                  ]),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
              child: pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: lightBg, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BILL TO',
                      style: pw.TextStyle(
                          color: textMid,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.2)),
                  pw.SizedBox(height: 6),
                  pw.Text(data.customerName,
                      style: pw.TextStyle(
                          color: textDark,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(data.customerEmail,
                      style: pw.TextStyle(color: textMid, fontSize: 9)),
                ]),
          )),
          pw.SizedBox(width: 16),
          pw.Expanded(
              child: pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: lightBg, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SHIP TO',
                      style: pw.TextStyle(
                          color: textMid,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.2)),
                  pw.SizedBox(height: 6),
                  pw.Text(data.deliveryAddress,
                      style: pw.TextStyle(
                          color: textDark, fontSize: 9, lineSpacing: 3)),
                ]),
          )),
          pw.SizedBox(width: 16),
          pw.Expanded(
              child: pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: lightBg, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PAYMENT',
                      style: pw.TextStyle(
                          color: textMid,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.2)),
                  pw.SizedBox(height: 6),
                  pw.Text(data.paymentMethod,
                      style: pw.TextStyle(
                          color: textDark,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                          color: cyan,
                          borderRadius: pw.BorderRadius.circular(10)),
                      child: pw.Text('PAID',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold))),
                ]),
          )),
        ]),
        pw.SizedBox(height: 24),
        pw.Container(
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: divider),
              borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(children: [
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const pw.BoxDecoration(color: navy),
              child: pw.Row(children: [
                pw.Expanded(
                    flex: 5,
                    child: pw.Text('ITEM',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1))),
                pw.SizedBox(
                    width: 50,
                    child: pw.Text('QTY',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(
                    width: 80,
                    child: pw.Text('UNIT PRICE',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(
                    width: 80,
                    child: pw.Text('TOTAL',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold))),
              ]),
            ),
            ...data.items.asMap().entries.map((entry) {
              final item = entry.value;
              return pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: entry.key % 2 == 0 ? PdfColors.white : lightBg,
                child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          flex: 5,
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(item.name,
                                    style: pw.TextStyle(
                                        color: textDark,
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 2),
                                pw.Text(item.description,
                                    style: pw.TextStyle(
                                        color: textMid, fontSize: 8)),
                              ])),
                      pw.SizedBox(
                          width: 50,
                          child: pw.Text('${item.qty}',
                              textAlign: pw.TextAlign.center,
                              style:
                                  pw.TextStyle(color: textDark, fontSize: 10))),
                      pw.SizedBox(
                          width: 80,
                          child: pw.Text(
                              '₹${item.unitPrice.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                              style:
                                  pw.TextStyle(color: textDark, fontSize: 10))),
                      pw.SizedBox(
                          width: 80,
                          child: pw.Text('₹${item.total.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  color: textDark,
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold))),
                    ]),
              );
            }),
          ]),
        ),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          pw.Spacer(),
          pw.Container(
            width: 260,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: lightBg, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(children: [
              _row('Subtotal', '₹${data.subtotal.toStringAsFixed(2)}', textDark,
                  textMid),
              pw.SizedBox(height: 6),
              _row('GST (${data.gstPercent.toInt()}%)',
                  '₹${data.gstAmount.toStringAsFixed(2)}', textDark, textMid),
              pw.SizedBox(height: 6),
              _row(
                  'Delivery Charge',
                  '₹${data.deliveryCharge.toStringAsFixed(2)}',
                  textDark,
                  textMid),
              pw.SizedBox(height: 8),
              pw.Divider(color: divider, thickness: 1),
              pw.SizedBox(height: 8),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GRAND TOTAL',
                        style: pw.TextStyle(
                            color: navy,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text('₹${data.grandTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            color: navy,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                  ]),
            ]),
          ),
        ]),
        pw.SizedBox(height: 32),
        pw.Divider(color: divider),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Thank you for shopping with PartMo!',
              style: pw.TextStyle(
                  color: textMid, fontSize: 9, fontStyle: pw.FontStyle.italic)),
          pw.Text('This is a computer-generated invoice.',
              style: pw.TextStyle(color: textMid, fontSize: 8)),
        ]),
      ],
    ));

    await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(), name: 'Invoice_${data.orderId}.pdf');
  }

  static pw.Widget _row(String label, String value, PdfColor vc, PdfColor lc) {
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(color: lc, fontSize: 10)),
          pw.Text(value,
              style: pw.TextStyle(
                  color: vc, fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ]);
  }
}
