import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive.dart';
import '../../providers/checkout_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/payment_method_tile.dart';

class PaymentSelectionScreen extends ConsumerWidget {
  const PaymentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    final selected = ref.watch(selectedPaymentProvider);

    return Scaffold(
      appBar: AppBar(
          title: const Text('Order Confirmation',
              style: TextStyle(fontWeight: FontWeight.w900))),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final method in methods)
                PaymentMethodTile(
                  method: method,
                  selected: method.id == selected,
                  onTap: () => ref
                      .read(selectedPaymentProvider.notifier)
                      .state = method.id,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
            child: AppButton(
                label: 'Back to Checkout', onPressed: () => context.pop()),
          ),
        ),
      ),
    );
  }
}
