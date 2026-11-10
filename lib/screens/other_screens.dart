import 'dart:async';
import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../navigation/nav.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../services/location_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'auth/login_screen.dart';
import 'prescription_screen.dart';
import 'order_tracking_screen.dart';
import 'pharmacist_admin_screen.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Medicines',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pharmacy inventory catalog.', style: t(14, c: C.sub)),
          const SizedBox(height: 16),
          ResponsiveGrid(minTileWidth: 300, children: [for (final m in medicines) MedicineTile(m)]),
        ]),
      );
}

class AllMedicinesScreen extends StatelessWidget {
  const AllMedicinesScreen({super.key});
  @override
  Widget build(BuildContext context) => const MedicinesScreen();
}

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Healthcare Products',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Available wellness essentials.', style: t(14, c: C.sub)),
          const SizedBox(height: 16),
          ResponsiveGrid(minTileWidth: 260, children: [
            for (final p in products)
              DawaSurface(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  IconChip(p.icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: t(15, w: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(p.category, style: t(12.5, c: C.sub)),
                    ]),
                  ),
                ]),
              ),
          ]),
        ]),
      );
}

class PharmaciesScreen extends StatelessWidget {
  const PharmaciesScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Nearby Pharmacies',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Verified partner pharmacies.', style: t(14, c: C.sub)),
          const SizedBox(height: 16),
          ResponsiveGrid(minTileWidth: 300, children: [
            for (final p in pharmacies) PharmacyCard(p, onTap: () => push(context, PharmacyDetailScreen(p))),
          ]),
        ]),
      );
}

class PharmacyDetailScreen extends StatelessWidget {
  final Pharmacy p;
  const PharmacyDetailScreen(this.p, {super.key});

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: p.name,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DawaSurface(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: C.light,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(p.icon, color: C.purple, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(p.name, style: t(20, w: FontWeight.w800, c: C.indigo))),
              ]),
              const SizedBox(height: 16),
              Text(p.description, style: t(14, c: C.sub, h: 1.5)),
              const SizedBox(height: 16),
              _info(Icons.location_on_outlined, p.area),
              _info(Icons.schedule_rounded, p.hours),
              _info(Icons.check_circle_outline_rounded, 'Verified partner: Open now', color: C.green),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Sample Inventory', subtitle: 'Frequently dispensed medicines'),
          ResponsiveGrid(minTileWidth: 300, children: [for (final m in medicines.take(4)) MedicineTile(m)]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.light,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: C.purple, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Real stock availability is confirmed dynamically when you upload and submit your prescription.',
                    style: t(13, c: C.indigo, h: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => push(context, const PrescriptionScreen()),
            icon: const Icon(Icons.document_scanner_rounded),
            label: const Text('Scan Prescription for This Pharmacy'),
          ),
        ]),
      );

  Widget _info(IconData i, String s, {Color color = C.sub}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(i, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(s, style: t(13.5, c: color == C.sub ? C.text : color, w: FontWeight.w500))),
        ]),
      );
}

class MyPrescriptionsScreen extends StatelessWidget {
  const MyPrescriptionsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Prescription Records',
        child: ValueListenableBuilder<List<PrescriptionRecord>>(
          valueListenable: prescriptionRecords,
          builder: (context, list, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (list.isEmpty)
              const EmptyState(Icons.description_outlined, 'No prescriptions yet',
                  'Prescriptions you upload will be safely organized here for your records.')
            else
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DawaSurface(
                    padding: const EdgeInsets.all(16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (r.bytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(r.bytes!, width: 68, height: 68, fit: BoxFit.cover),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_fmt(r.date), style: t(12, c: C.sub)),
                          const SizedBox(height: 4),
                          Text(r.items.join(', '), style: t(14.5, w: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('Prescription logged on this device.', style: t(12, c: C.sub)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => push(context, const PrescriptionScreen()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Upload New Prescription'),
            ),
          ]),
        ),
      );

  static String _fmt(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${m[d.month - 1]} ${d.year}, ${d.hour}:$mm';
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _medicines = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    LocationState.instance.addListener(_onLocationChanged);
    _fetchMedicines();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    LocationState.instance.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) _fetchMedicines();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _query = val.trim());
      _fetchMedicines();
    });
  }

  Future<void> _fetchMedicines() async {
    final loc = LocationState.instance;
    if (!loc.hasLocation) {
      if (!mounted) return;
      setState(() {
        _medicines = [];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.instance.getMedicinesNearby(
        lat: loc.lat!,
        lng: loc.lng!,
        q: _query.isNotEmpty ? _query : null,
      );
      if (!mounted) return;
      setState(() {
        _medicines = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load nearby medicines stock';
        _loading = false;
      });
    }
  }

  void _showPharmacyStockSheet(Map<String, dynamic> med) {
    final name = med['name'] ?? 'Medicine';
    final strength = med['strength'] ?? '';
    final form = med['form'] ?? '';
    final pharmacies = (med['pharmacies'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          int? placingId;

          return Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: t(19, w: FontWeight.w800, c: C.text)),
                          if (strength.toString().isNotEmpty || form.toString().isNotEmpty)
                            Text('$strength • $form', style: t(13, c: C.sub)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Available at ${pharmacies.length} nearby registered pharmacies:',
                  style: t(13.5, w: FontWeight.w600, c: C.sub),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pharmacies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final p = pharmacies[i];
                      final phId = p['pharmacy_id'] as int;
                      final phName = p['name'] ?? 'Pharmacy';
                      final dist = (p['distance_km'] as num?)?.toDouble() ?? 0.0;
                      final price = (p['price'] as num?)?.toDouble() ?? 0.0;
                      final qty = (p['quantity'] as num?)?.toInt() ?? 0;
                      final isOrdering = placingId == phId;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(phName, style: t(15, w: FontWeight.w700, c: C.text)),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${dist.toStringAsFixed(1)} km away • $qty in stock',
                                    style: t(12, c: C.sub),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs. ${price.toStringAsFixed(0)}',
                                    style: t(15, w: FontWeight.w800, c: C.purple),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: isOrdering
                                  ? null
                                  : () async {
                                      setModalState(() => placingId = phId);
                                      try {
                                        final res = await ApiService.instance.createPatientOrder(
                                          pharmacyId: phId,
                                          items: [
                                            {
                                              'name': name,
                                              'strength': strength,
                                              'form': form,
                                              'price': price,
                                              'quantity': 1,
                                            }
                                          ],
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (!mounted) return;
                                        if (res != null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Order placed with $phName!')),
                                          );
                                          tabIndex.value = 2; // Switch to Orders
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Failed to place order')),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          setModalState(() => placingId = null);
                                        }
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: C.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: isOrdering
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Order Here'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocationState.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideEntrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore Medicines', style: t(28, w: FontWeight.w800, c: C.indigo, ls: -0.4)),
                const SizedBox(height: 4),
                Text(
                  'Browse real-time stock at registered pharmacies near you.',
                  style: t(14, c: C.sub),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Search Field
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search medicines by name, brand, or formula...',
              hintStyle: t(14, c: C.sub),
              prefixIcon: const Icon(Icons.search_rounded, color: C.purple),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                        _fetchMedicines();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: C.purple, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Content body states
          if (!loc.hasLocation)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.location_off_outlined, size: 54, color: C.sub),
                    const SizedBox(height: 14),
                    Text('Location required to view stock', style: t(16, w: FontWeight.w700, c: C.text)),
                    const SizedBox(height: 6),
                    Text(
                      'Please choose a location to discover registered pharmacy stock nearby.',
                      style: t(13.5, c: C.sub),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => showLocationPickerSheet(context),
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Choose Location'),
                    ),
                  ],
                ),
              ),
            )
          else if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(50),
                child: CircularProgressIndicator(color: C.purple, strokeWidth: 2.5),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: C.red),
                    const SizedBox(height: 12),
                    Text(_error!, style: t(15, w: FontWeight.w600, c: C.red)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _fetchMedicines,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_medicines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.medication_outlined, size: 56, color: C.sub),
                    const SizedBox(height: 14),
                    Text('No medicines in stock', style: t(17, w: FontWeight.w800, c: C.text)),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Text(
                        'No medicines in stock near ${loc.label.isNotEmpty ? loc.label : "your location"}. Try a larger area or change location.',
                        textAlign: TextAlign.center,
                        style: t(13.5, c: C.sub),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => showLocationPickerSheet(context),
                      child: const Text('Change Location'),
                    ),
                  ],
                ),
              ),
            )
          else
            ResponsiveGrid(
              minTileWidth: 320,
              children: [
                for (final med in _medicines)
                  _buildMedicineCard(med),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> med) {
    final name = med['name'] ?? 'Medicine';
    final strength = med['strength'] ?? '';
    final form = med['form'] ?? '';
    final minPrice = (med['min_price'] as num?)?.toDouble() ?? 0.0;
    final phs = (med['pharmacies'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final nearestPh = phs.isNotEmpty ? phs.first : null;
    final nearestName = nearestPh?['name'] ?? 'Pharmacy';
    final nearestDist = (nearestPh?['distance_km'] as num?)?.toDouble() ?? 0.0;

    return DawaSurface(
      padding: const EdgeInsets.all(18),
      onTap: () => _showPharmacyStockSheet(med),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.light,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_rounded, color: C.purple, size: 22),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: C.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('In Stock', style: t(11, w: FontWeight.w700, c: C.green)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(name, style: t(16, w: FontWeight.w800, c: C.text)),
          const SizedBox(height: 3),
          Text(
            '${strength.toString().isNotEmpty ? "$strength • " : ""}$form',
            style: t(13, c: C.sub),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 14, color: C.sub),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$nearestName (${nearestDist.toStringAsFixed(1)} km)',
                  style: t(12, c: C.sub),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'from Rs. ${minPrice.toStringAsFixed(0)}',
                style: t(15.5, w: FontWeight.w800, c: C.purple),
              ),
              Text('View Pharmacies →', style: t(12.5, w: FontWeight.w700, c: C.purple)),
            ],
          ),
        ],
      ),
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _selectedStatus = 'All';

  static const List<String> _statusFilters = [
    'All',
    'Pending',
    'Accepted',
    'Ready',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.instance.getMyOrders();
      if (mounted) {
        setState(() {
          _orders = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedStatus == 'All') return _orders;
    return _orders.where((o) {
      final st = (o['status'] ?? '').toString().toLowerCase();
      return st == _selectedStatus.toLowerCase();
    }).toList();
  }

  Future<void> _cancelOrder(int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Order', style: t(17, w: FontWeight.w700, c: C.red)),
        content: const Text('Are you sure you want to cancel this pending order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Order')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: C.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ApiService.instance.cancelPatientOrder(orderId);
      if (res != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully.')),
        );
        _fetchOrders();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel order')),
        );
      }
    }
  }

  bool _isPending(String status) {
    final s = status.toLowerCase();
    return s == 'pending' || s == 'order placed' || s == 'awaiting pharmacist verification';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FadeSlideEntrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Orders', style: t(28, w: FontWeight.w800, c: C.indigo, ls: -0.4)),
                    const SizedBox(height: 4),
                    Text('Track live status and order fulfillment.', style: t(14, c: C.sub)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: C.purple),
                tooltip: 'Refresh Orders',
                onPressed: _fetchOrders,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters.map((f) {
                final isSel = _selectedStatus == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    labelStyle: t(
                      13,
                      w: isSel ? FontWeight.w700 : FontWeight.w500,
                      c: isSel ? Colors.white : C.text,
                    ),
                    selected: isSel,
                    selectedColor: C.purple,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isSel ? C.purple : C.border),
                    ),
                    onSelected: (_) => setState(() => _selectedStatus = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: C.purple, strokeWidth: 2.5),
              ),
            )
          else if (_filteredOrders.isEmpty)
            const EmptyState(
              Icons.inventory_2_outlined,
              'No orders found',
              'Confirmed and active orders will appear here with live updates.',
            )
          else
            for (int i = 0; i < _filteredOrders.length; i++)
              _buildOrderCard(_filteredOrders[i], i),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final id = order['id'] as int;
    final status = (order['status'] ?? 'pending').toString();
    final canCancel = _isPending(status);
    final orderNum = order['order_number'] ?? order['order_reference'] ?? 'DAWA-$id';
    final phName = order['pharmacy_name'] ?? 'Pharmacy';
    final fulfillment = order['fulfillment_type'] ?? order['fulfillment_method'] ?? 'Pickup';
    final total = (order['total'] ?? order['total_amount'] ?? 0.0) as num;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FadeSlideEntrance(
        delay: Duration(milliseconds: 60 * index),
        child: DawaSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(orderNum, style: t(16, w: FontWeight.w800, c: C.indigo)),
                  DawaBadge(
                    label: status.toUpperCase(),
                    bg: const Color(0xFFF1EDFF),
                    text: C.purple,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('$phName • $fulfillment', style: t(13, c: C.sub)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PKR ${total.toStringAsFixed(0)}', style: t(15.5, w: FontWeight.w800, c: C.text)),
                  Row(
                    children: [
                      if (canCancel) ...[
                        OutlinedButton(
                          onPressed: () => _cancelOrder(id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: C.red,
                            side: const BorderSide(color: C.red),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel Order'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton.icon(
                        onPressed: () => push(context, OrderTrackingScreen(order: order)),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: C.purple),
                        label: Text('Track Order', style: t(13, w: FontWeight.w700, c: C.purple)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 1. Luxury Profile Header Card with Ambient Glow
      ListenableBuilder(
        listenable: AuthState.instance,
        builder: (ctx, _) {
          final auth = AuthState.instance;
          final userName = auth.user?.name.isNotEmpty == true ? auth.user!.name : 'User';
          final roleLabel = auth.isPharmacyAdmin ? 'Pharmacy Admin' : 'Patient';

          return IlluminatedCard(
            padding: const EdgeInsets.all(22),
            child: Row(children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(userName),
                    style: t(20, w: FontWeight.w800, c: C.purple),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(userName, style: t(19, w: FontWeight.w800, c: Colors.white)),
                  const SizedBox(height: 2),
                  Text(roleLabel, style: t(13, c: const Color(0xFFDDD6FE))),
                ]),
              ),
            ]),
          );
        },
      ),
      const SizedBox(height: 20),

      // 2. Settings Rows
      ListenableBuilder(
        listenable: LocationState.instance,
        builder: (ctx, _) {
          final s = LocationState.instance;
          final sub = s.source == 'none' || s.label.isEmpty
              ? 'Set your location'
              : s.label;
          return _tile(
            Icons.location_on_outlined,
            'Delivery Location',
            sub,
            () => showLocationPickerSheet(context),
          );
        },
      ),
      _tile(Icons.description_outlined, 'My Prescriptions', 'View uploaded prescription history', () => push(context, const MyPrescriptionsScreen())),
      if (AuthState.instance.isPharmacyAdmin)
        _tile(Icons.admin_panel_settings_outlined, 'Pharmacist Operations Portal', 'Verify prescriptions and update order milestones', () => push(context, const PharmacistAdminScreen())),
      _tile(Icons.notifications_none_rounded, 'Notifications', 'Manage order and fulfillment alerts', () => push(context, const NotificationsScreen())),
      _tile(Icons.health_and_safety_outlined, 'Healthcare Safety Guarantee', 'Every prescription is verified by a qualified pharmacist.', null),
      _tile(Icons.info_outline_rounded, 'About DAWA', 'Connecting You to Better Healthcare • v1.0.0', null),
      _tile(
        Icons.logout_rounded,
        'Log Out',
        'Sign out of your DAWA account',
        () async {
          await AuthState.instance.logout();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
      ),
    ]);

    if (embedded) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FadeSlideEntrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile', style: t(28, w: FontWeight.w800, c: C.indigo, ls: -0.4)),
                const SizedBox(height: 4),
                Text('Account preferences, records, and operations.', style: t(14, c: C.sub)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          body,
        ]),
      );
    }
    return PageScaffold(title: 'Profile', child: body);
  }

  Widget _tile(IconData i, String title, String sub, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DawaSurface(
          padding: const EdgeInsets.all(16),
          onTap: onTap,
          child: Row(children: [
            IconChip(i, size: 42, iconSize: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t(15, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: t(12.5, c: C.sub)),
              ]),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: C.sub, size: 20),
          ]),
        ),
      );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Notifications',
        child: Column(children: [
          for (final n in notifications)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DawaSurface(
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconChip(Icons.notifications_none_rounded, size: 42, iconSize: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(n.title, style: t(15, w: FontWeight.w700))),
                        Text(n.time, style: t(12, c: C.sub)),
                      ]),
                      const SizedBox(height: 4),
                      Text(n.body, style: t(13, c: C.sub, h: 1.4)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      );
}
