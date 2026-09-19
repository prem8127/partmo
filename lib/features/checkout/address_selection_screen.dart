import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive.dart';
import '../../models/address.dart';
import '../../providers/checkout_provider.dart';
import '../../widgets/address_card.dart';
import '../../widgets/app_button.dart';

class AddressSelectionScreen extends ConsumerStatefulWidget {
  const AddressSelectionScreen({super.key});

  @override
  ConsumerState<AddressSelectionScreen> createState() =>
      _AddressSelectionScreenState();
}

class _AddressSelectionScreenState
    extends ConsumerState<AddressSelectionScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
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
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _addOrEditAddress(BuildContext context, WidgetRef ref,
      {Address? existing}) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final lineCtrl = TextEditingController(text: existing?.line ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final alternateCtrl =
        TextEditingController(text: existing?.alternatePhone ?? '');
    var saving = false;

    return showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(
              existing == null
                  ? 'Add delivery address'
                  : 'Edit delivery address',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Label (e.g. Home, Office)')),
                const SizedBox(height: 10),
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Recipient name')),
                const SizedBox(height: 10),
                TextField(
                    controller: lineCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Address line')),
                const SizedBox(height: 10),
                TextField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(
                        labelText: 'City, state, pincode')),
                const SizedBox(height: 10),
                TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '10-digit mobile number',
                        counterText: '')),
                const SizedBox(height: 10),
                TextField(
                    controller: alternateCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Alternative mobile number (optional)',
                        hintText: '10 digits',
                        counterText: '')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final phoneDigits =
                          phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                      final alternateDigits =
                          alternateCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                      if (labelCtrl.text.trim().isEmpty ||
                          nameCtrl.text.trim().isEmpty ||
                          lineCtrl.text.trim().isEmpty ||
                          cityCtrl.text.trim().isEmpty ||
                          phoneDigits.length != 10 ||
                          (alternateDigits.isNotEmpty &&
                              alternateDigits.length != 10)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Complete every required field and enter valid 10-digit mobile numbers.'),
                          ),
                        );
                        return;
                      }
                      final address = Address(
                        id: existing?.id ??
                            'addr${DateTime.now().microsecondsSinceEpoch}',
                        label: labelCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        line: lineCtrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        alternatePhone: alternateDigits,
                        isDefault: existing?.isDefault ?? false,
                      );
                      setDialogState(() => saving = true);
                      try {
                        if (existing == null) {
                          final saved = await ref
                              .read(addressesProvider.notifier)
                              .addAddress(address);
                          await ref
                              .read(selectedAddressProvider.notifier)
                              .select(saved.id);
                        } else {
                          await ref
                              .read(addressesProvider.notifier)
                              .updateAddress(address);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Could not save address: $error'),
                          ));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('SAVE'),
            ),
          ],
        );
      }),
    ).whenComplete(() {
      labelCtrl.dispose();
      nameCtrl.dispose();
      lineCtrl.dispose();
      cityCtrl.dispose();
      phoneCtrl.dispose();
      alternateCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    final selected = ref.watch(selectedAddressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Address',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () => _addOrEditAddress(context, ref),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add new address',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : addresses.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('No saved addresses yet',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('Add a delivery address to continue.',
                              style: TextStyle(color: Color(0xFF7D8B97))),
                          const SizedBox(height: 20),
                          AppButton(
                            label: 'Add Address',
                            icon: Icons.add,
                            expanded: false,
                            onPressed: () => _addOrEditAddress(context, ref),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Saved addresses (${addresses.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final address in addresses)
                          AddressCard(
                            address: address,
                            selected: address.id == selected,
                            onTap: () => ref
                                .read(selectedAddressProvider.notifier)
                                .select(address.id),
                            onEdit: () => _addOrEditAddress(context, ref,
                                existing: address),
                            onDelete: () => _deleteAddress(context, address),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _addOrEditAddress(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Add new address',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                        ),
                      ],
                    ),
        ),
      ),
      bottomNavigationBar: _loading || addresses.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: Responsive.maxWidth(context)),
                  child: AppButton(
                    label: 'Deliver to this address',
                    icon: Icons.local_shipping_outlined,
                    onPressed:
                        selected.isEmpty ? null : () => context.pop(selected),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _deleteAddress(BuildContext context, Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove ${address.label} from your saved addresses?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('DELETE')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(addressesProvider.notifier).removeAddress(address.id);
    if (ref.read(selectedAddressProvider) == address.id) {
      final remaining = ref.read(addressesProvider);
      await ref
          .read(selectedAddressProvider.notifier)
          .select(remaining.isEmpty ? '' : remaining.first.id);
    }
  }
}
