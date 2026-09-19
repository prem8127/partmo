import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';

class AdminProductEnquiriesScreen extends StatefulWidget {
  const AdminProductEnquiriesScreen({super.key});

  @override
  State<AdminProductEnquiriesScreen> createState() =>
      _AdminProductEnquiriesScreenState();
}

class _AdminProductEnquiriesScreenState
    extends State<AdminProductEnquiriesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.fetchProductEnquiries();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load product enquiries.';
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    await SupabaseService.updateProductEnquiry(id, {'status': status});
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(
                    8,
                    MediaQuery.paddingOf(context).top + 10,
                    12,
                    12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/admin'),
                        icon: const Icon(Icons.arrow_back,
                            color: AppPalette.navy),
                      ),
                      const Expanded(
                        child: Text(
                          'Product Enquiries',
                          style: TextStyle(
                            color: AppPalette.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, color: AppPalette.navy),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 90),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(_error!,
                        style: const TextStyle(color: AppPalette.danger)),
                  )
                else if (_rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 90),
                    child: Center(
                      child: Text(
                        'No product enquiries yet.',
                        style: TextStyle(
                            color: AppPalette.muted,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        for (final row in _rows)
                          _EnquiryCard(row: row, onStatus: _setStatus),
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

class _EnquiryCard extends StatelessWidget {
  const _EnquiryCard({required this.row, required this.onStatus});

  final Map<String, dynamic> row;
  final Future<void> Function(Map<String, dynamic> row, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    final imageUrl = row['image_url']?.toString() ?? '';
    final status = row['status']?.toString() ?? 'new';
    final customerName = row['customer_name']?.toString() ?? 'Customer';
    final email = row['customer_email']?.toString() ?? '';
    final phone = row['customer_phone']?.toString() ?? '';
    final description = row['description']?.toString() ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  customerName,
                  style: const TextStyle(
                    color: AppPalette.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F8F1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: AppPalette.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (phone.isNotEmpty || email.isNotEmpty)
            Text(
              [phone, email].where((v) => v.isNotEmpty).join(' • '),
              style: const TextStyle(
                color: AppPalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF172635),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: const Color(0xFFEFF4FA),
                  alignment: Alignment.center,
                  child: const Text('Image could not load'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onStatus(row, 'contacted'),
                  child: const Text('Contacted'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => onStatus(row, 'closed'),
                  child: const Text('Closed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
