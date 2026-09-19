import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/models/address.dart';
import 'package:precision_parts_frontend/providers/checkout_provider.dart';

void main() {
  test('server and device address copies merge without losing local data', () {
    const server = Address(
      id: 'server-id',
      label: 'Home',
      name: 'Akhil',
      line: '1 Main Road',
      city: 'Hyderabad',
      phone: '9876543210',
    );
    const sameLocalAddress = Address(
      id: 'addr-local-copy',
      label: ' home ',
      name: 'AKHIL',
      line: '1 MAIN ROAD',
      city: 'Hyderabad',
      phone: '9876543210',
    );
    const localOnly = Address(
      id: 'addr-office',
      label: 'Office',
      name: 'Akhil',
      line: '2 Work Street',
      city: 'Hyderabad',
      phone: '9876543210',
    );

    final merged = mergeAddressCopies([server, sameLocalAddress, localOnly]);

    expect(merged, hasLength(2));
    expect(merged.first.id, 'server-id');
    expect(merged.last.id, 'addr-office');
  });
}
