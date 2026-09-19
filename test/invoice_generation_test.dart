import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/core/services/invoice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invoice uses persisted totals and renders a professional preview',
      () async {
    const data = InvoiceData(
      orderId: '#PP-20919-CP',
      orderDate: '03 Sep 2026',
      customerName: 'Akhil Kumar',
      customerEmail: 'akhil@example.com',
      deliveryAddress:
          '42, West Lake Block, Jubilee Hills, Hyderabad, Telangana 500033',
      paymentMethod: 'Payment Pending',
      deliveryCharge: 0,
      subtotalAmount: 2451,
      gstAmountValue: 441.18,
      grandTotalAmount: 2892.18,
      items: [
        InvoiceItem(
          name: 'Air Filter for Toyota Innova Crysta',
          description: 'Filters',
          qty: 1,
          unitPrice: 1,
        ),
        InvoiceItem(
          name: 'Water Pump for Toyota Innova Crysta',
          description: 'Engine cooling system',
          qty: 1,
          unitPrice: 2450,
        ),
      ],
    );

    expect(data.subtotal, 2451);
    expect(data.gstAmount, 441.18);
    expect(data.grandTotal, 2892.18);

    final bytes = await InvoiceService.buildInvoice(data);
    expect(bytes.length, greaterThan(10000));

    final directory = Directory('output/pdf');
    await directory.create(recursive: true);
    await File('${directory.path}/PartMo_Invoice_Preview.pdf')
        .writeAsBytes(bytes, flush: true);

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
