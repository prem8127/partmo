import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/core/services/invoice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('write invoice visual fixture', () async {
    const data = InvoiceData(
      orderId: 'PP-20919-CP',
      orderDate: '2026-09-03',
      customerName: 'Akhil Kumar',
      customerEmail: 'akhil@example.com',
      deliveryAddress:
          '42, West Lake Block, Jubilee Hills, Hyderabad, Telangana 500033',
      items: [
        InvoiceItem(
          name: 'Air Filter for Toyota Innova Crysta',
          description: 'Engine air filter - genuine compatible part',
          qty: 1,
          unitPrice: 2450,
        ),
        InvoiceItem(
          name: 'Front Brake Pad Set for Hyundai Creta',
          description: 'Front axle brake pad set',
          qty: 1,
          unitPrice: 1650,
        ),
      ],
      deliveryCharge: 0,
      paymentMethod: 'Payment Pending',
      subtotalAmount: 4100,
      gstAmountValue: 738,
      grandTotalAmount: 4838,
    );
    final bytes = await InvoiceService.buildInvoice(data);
    final output = File('output/pdf/PartMo_Invoice_Preview.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes);
    expect(await output.length(), greaterThan(10000));
  });
}
