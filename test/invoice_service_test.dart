import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/core/services/invoice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const data = InvoiceData(
    orderId: 'PP-TEST-1001',
    orderDate: '2026-09-03',
    customerName: 'Test Customer',
    customerEmail: 'customer@example.com',
    deliveryAddress: '12 Test Road, Hyderabad, Telangana 500001',
    items: [
      InvoiceItem(
        name: 'Front Brake Pad Set',
        description: 'Brakes',
        qty: 1,
        unitPrice: 2450,
      ),
    ],
    deliveryCharge: 0,
    paymentMethod: 'Payment Pending',
    subtotalAmount: 2450,
    gstAmountValue: 441,
    grandTotalAmount: 2891,
  );

  test('persisted order totals are not taxed twice', () {
    expect(data.subtotal, 2450);
    expect(data.gstAmount, 441);
    expect(data.grandTotal, 2891);
  });

  test('professional invoice builds as a valid PDF', () async {
    final bytes = await InvoiceService.buildInvoice(data);
    expect(bytes.length, greaterThan(10000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
