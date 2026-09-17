import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceItem {
  const InvoiceItem({
    required this.name,
    required this.description,
    required this.qty,
    required this.unitPrice,
  });

  final String name;
  final String description;
  final int qty;
  final double unitPrice;

  double get total => qty * unitPrice;
}

class InvoiceData {
  const InvoiceData({
    required this.orderId,
    required this.orderDate,
    required this.customerName,
    required this.customerEmail,
    required this.deliveryAddress,
    required this.items,
    required this.deliveryCharge,
    required this.paymentMethod,
    this.gstPercent = 18,
    this.subtotalAmount,
    this.gstAmountValue,
    this.grandTotalAmount,
  });

  final String orderId;
  final String orderDate;
  final String customerName;
  final String customerEmail;
  final String deliveryAddress;
  final List<InvoiceItem> items;
  final double deliveryCharge;
  final String paymentMethod;
  final double gstPercent;
  final double? subtotalAmount;
  final double? gstAmountValue;
  final double? grandTotalAmount;

  double get subtotal =>
      subtotalAmount ?? items.fold(0, (sum, item) => sum + item.total);
  double get gstAmount => gstAmountValue ?? subtotal * gstPercent / 100;
  double get grandTotal =>
      grandTotalAmount ?? subtotal + gstAmount + deliveryCharge;

  bool get isPaymentPending =>
      paymentMethod.toLowerCase().contains('pending') || paymentMethod.isEmpty;
}

class InvoiceService {
  static const _navy = PdfColor.fromInt(0xFF073B63);
  static const _cyan = PdfColor.fromInt(0xFF18B8E8);
  static const _ink = PdfColor.fromInt(0xFF172635);
  static const _muted = PdfColor.fromInt(0xFF66788A);
  static const _surface = PdfColor.fromInt(0xFFF4F7FB);
  static const _line = PdfColor.fromInt(0xFFDCE5ED);
  static const _success = PdfColor.fromInt(0xFF2A9D68);
  static const _warning = PdfColor.fromInt(0xFFF2A900);

  static Future<Uint8List> buildInvoice(InvoiceData data) async {
    final fontData = await rootBundle.load('assets/fonts/Roboto-Variable.ttf');
    final font = pw.Font.ttf(fontData);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font, italic: font),
      title: 'PartMo Invoice ${data.orderId}',
      author: 'PartMo',
      creator: 'PartMo Order System',
      subject: 'Order invoice',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 34, 38, 34),
        footer: (context) => _footer(context),
        build: (_) => [
          _header(data),
          pw.SizedBox(height: 22),
          _partyAndPayment(data),
          pw.SizedBox(height: 22),
          _itemsTable(data),
          pw.SizedBox(height: 18),
          _summary(data),
          pw.SizedBox(height: 24),
          _notice(data),
        ],
      ),
    );

    return document.save();
  }

  static Future<void> downloadInvoice(InvoiceData data) async {
    final bytes = await buildInvoice(data);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'PartMo_Invoice_${_safeFilePart(data.orderId)}.pdf',
    );
  }

  static pw.Widget _header(InvoiceData data) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 46,
              height: 46,
              decoration: pw.BoxDecoration(
                color: _navy,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text('P',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 25,
                      fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PARTMO',
                      style: pw.TextStyle(
                          color: _navy,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.1)),
                  pw.SizedBox(height: 2),
                  pw.Text('Verified automotive spare parts',
                      style: const pw.TextStyle(color: _muted, fontSize: 9)),
                  pw.SizedBox(height: 2),
                  pw.Text('support@partmo.in  |  www.partmo.in',
                      style: const pw.TextStyle(color: _muted, fontSize: 8)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('ORDER INVOICE',
                    style: pw.TextStyle(
                        color: _navy,
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                _metaLine('Invoice no.', data.orderId),
                pw.SizedBox(height: 3),
                _metaLine('Invoice date', data.orderDate),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(height: 3, color: _cyan),
      ],
    );
  }

  static pw.Widget _partyAndPayment(InvoiceData data) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _infoCard(
            'BILLED TO',
            [
              data.customerName.trim().isEmpty ? 'Customer' : data.customerName,
              if (data.customerEmail.trim().isNotEmpty) data.customerEmail,
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _infoCard(
            'DELIVER TO',
            [
              data.deliveryAddress.trim().isEmpty
                  ? 'Not provided'
                  : data.deliveryAddress
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(13),
            decoration: pw.BoxDecoration(
              color: _surface,
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionLabel('PAYMENT'),
                pw.SizedBox(height: 7),
                pw.Text(data.paymentMethod,
                    style: pw.TextStyle(
                        color: _ink,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: data.isPaymentPending ? _warning : _success,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Text(
                    data.isPaymentPending ? 'PAYMENT PENDING' : 'PAID',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: .4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _itemsTable(InvoiceData data) {
    final rows = data.items.isEmpty
        ? const [
            InvoiceItem(
                name: 'Automotive spare part',
                description: '',
                qty: 1,
                unitPrice: 0)
          ]
        : data.items;
    return pw.Table(
      border: pw.TableBorder(
        left: const pw.BorderSide(color: _line),
        right: const pw.BorderSide(color: _line),
        bottom: const pw.BorderSide(color: _line),
        horizontalInside: const pw.BorderSide(color: _line),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navy),
          children: [
            _tableHeader('ITEM DESCRIPTION', pw.TextAlign.left),
            _tableHeader('QTY', pw.TextAlign.center),
            _tableHeader('RATE', pw.TextAlign.right),
            _tableHeader('AMOUNT', pw.TextAlign.right),
          ],
        ),
        for (final entry in rows.asMap().entries)
          pw.TableRow(
            decoration: pw.BoxDecoration(
                color: entry.key.isEven ? PdfColors.white : _surface),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(entry.value.name,
                        style: pw.TextStyle(
                            color: _ink,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                    if (entry.value.description.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(entry.value.description,
                          style:
                              const pw.TextStyle(color: _muted, fontSize: 8)),
                    ],
                  ],
                ),
              ),
              _tableCell('${entry.value.qty}', pw.TextAlign.center),
              _tableCell(_money(entry.value.unitPrice), pw.TextAlign.right),
              _tableCell(_money(entry.value.total), pw.TextAlign.right,
                  bold: true),
            ],
          ),
      ],
    );
  }

  static pw.Widget _summary(InvoiceData data) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(13),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionLabel('ORDER NOTE'),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Keep this invoice for order support, returns, and warranty-related enquiries.',
                  style: const pw.TextStyle(
                      color: _muted, fontSize: 8.5, lineSpacing: 2),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 22),
        pw.SizedBox(
          width: 245,
          child: pw.Column(
            children: [
              _totalRow('Subtotal', _money(data.subtotal)),
              pw.SizedBox(height: 7),
              _totalRow('GST (${data.gstPercent.toStringAsFixed(0)}%)',
                  _money(data.gstAmount)),
              pw.SizedBox(height: 7),
              _totalRow(
                  'Delivery',
                  data.deliveryCharge == 0
                      ? 'FREE'
                      : _money(data.deliveryCharge)),
              pw.SizedBox(height: 10),
              pw.Container(height: 1, color: _line),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                          color: _navy,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(_money(data.grandTotal),
                      style: pw.TextStyle(
                          color: _navy,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _notice(InvoiceData data) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(13),
      decoration: pw.BoxDecoration(
        color: data.isPaymentPending
            ? const PdfColor.fromInt(0xFFFFF7DF)
            : const PdfColor.fromInt(0xFFEAF8F1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        data.isPaymentPending
            ? 'Order confirmed. Payment has not been collected through this app.'
            : 'Payment recorded. Thank you for choosing PartMo.',
        style: pw.TextStyle(
            color: data.isPaymentPending ? _warning : _success,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(height: 1, color: _line),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('PartMo  |  support@partmo.in',
                style: const pw.TextStyle(color: _muted, fontSize: 8)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(color: _muted, fontSize: 8)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _infoCard(String title, List<String> lines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(13),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionLabel(title),
          pw.SizedBox(height: 7),
          for (var index = 0; index < lines.length; index++) ...[
            pw.Text(lines[index],
                style: pw.TextStyle(
                    color: index == 0 ? _ink : _muted,
                    fontSize: index == 0 ? 10 : 8.5,
                    fontWeight:
                        index == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                    lineSpacing: 2)),
            if (index < lines.length - 1) pw.SizedBox(height: 3),
          ],
        ],
      ),
    );
  }

  static pw.Widget _sectionLabel(String text) => pw.Text(text,
      style: pw.TextStyle(
          color: _muted,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1));

  static pw.Widget _metaLine(String label, String value) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label  ',
              style: const pw.TextStyle(color: _muted, fontSize: 8)),
          pw.Text(value,
              style: pw.TextStyle(
                  color: _ink, fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      );

  static pw.Widget _tableHeader(String text, pw.TextAlign align) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: .5)),
      );

  static pw.Widget _tableCell(String text, pw.TextAlign align,
          {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                color: _ink,
                fontSize: 9.5,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _totalRow(String label, String value) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: _muted, fontSize: 9)),
          pw.Text(value,
              style: pw.TextStyle(
                  color: _ink, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      );

  static String _money(double value) => '₹ ${_number(value)}';

  static String _number(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return '$buffer.${parts.last}';
  }

  static String _safeFilePart(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
}
