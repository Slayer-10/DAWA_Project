import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Accepted', 'Ready', 'Completed'
  Timer? _pollTimer;

  static const List<String> _filters = [
    'All',
    'Pending',
    'Accepted',
    'Ready',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    // Poll every 20 seconds while visible
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _fetchOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    try {
      final data = await ApiService.instance.getAdminOrders();
      if (!mounted) return;
      setState(() {
        _orders = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 'All') return _orders;
    return _orders.where((o) {
      final st = (o['status'] ?? '').toString().toLowerCase();
      return st == _selectedFilter.toLowerCase();
    }).toList();
  }

  Future<void> _updateStatus(int orderId, String targetStatus, {String? reason}) async {
    final index = _orders.indexWhere((o) => o['id'] == orderId);
    if (index == -1) return;

    final oldOrder = Map<String, dynamic>.from(_orders[index]);
    final oldStatus = oldOrder['status'];

    // Optimistic update
    setState(() {
      _orders[index]['status'] = targetStatus;
    });

    try {
      final res = await ApiService.instance.updateAdminOrderStatus(
        orderId,
        targetStatus,
        reason: reason,
      );

      if (res == null) {
        // Rollback on failure
        if (!mounted) return;
        setState(() {
          _orders[index]['status'] = oldStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update order status. Rolled back.')),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _orders[index] = res;
        });
      }
    } catch (e) {
      // Rollback on error
      if (!mounted) return;
      setState(() {
        _orders[index]['status'] = oldStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _confirmReject(int orderId) {
    final reasonCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Order', style: t(17, w: FontWeight.w700, c: C.danger)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject this order? Please state a reason:', style: t(13)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Out of requested stock',
                hintStyle: t(13, c: C.sub),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: t(14, c: C.sub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(orderId, 'rejected', reason: reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: C.danger),
            child: const Text('Reject Order'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'order placed':
      case 'awaiting pharmacist verification':
        return C.amber;
      case 'accepted':
      case 'preparing order':
        return C.purple;
      case 'ready':
      case 'ready for pickup':
        return C.indigo;
      case 'completed':
      case 'delivered':
      case 'collected':
        return C.green;
      case 'rejected':
      case 'cancelled':
        return C.red;
      default:
        return C.sub;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Chips Row
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final f = _filters[i];
              final isSel = _selectedFilter == f;
              return ChoiceChip(
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
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSel ? C.purple : C.border),
                ),
                onSelected: (_) => setState(() => _selectedFilter = f),
              );
            },
          ),
        ),

        // Orders List with Pull-to-refresh
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchOrders(),
            color: C.purple,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: C.purple))
                : _filteredOrders.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          EmptyState(
                            Icons.receipt_long_outlined,
                            'No Orders Found',
                            'Incoming patient orders for your pharmacy will appear here live.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (ctx, i) {
                          final o = _filteredOrders[i];
                          final id = o['id'] as int;
                          final patientName = (o['patient_name'] as String?)?.isNotEmpty == true
                              ? o['patient_name']
                              : 'Patient #${o['user_id'] ?? o['patient_id'] ?? id}';
                          final patientPhone = o['patient_phone'] as String?;
                          final status = (o['status'] ?? 'pending').toString().toLowerCase();
                          final total = (o['total'] ?? o['total_amount'] ?? 0.0) as num;
                          final timeStr = _formatTime(o['created_at']);
                          final items = (o['items'] as List?) ?? [];
                          final orderNumber = o['order_number'] ?? 'DAWA-$id';

                          final stColor = _getStatusColor(status);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: C.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top header: Order # + Status chip + Time
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: C.light,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        orderNumber,
                                        style: t(12, w: FontWeight.w700, c: C.purple),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: stColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: stColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(color: stColor, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            status.toUpperCase(),
                                            style: t(11, w: FontWeight.w700, c: stColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(timeStr, style: t(12, c: C.sub)),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Patient Name & Phone
                                Row(
                                  children: [
                                    const Icon(Icons.person_rounded, size: 16, color: C.sub),
                                    const SizedBox(width: 6),
                                    Text(
                                      patientName,
                                      style: t(15, w: FontWeight.w700, c: C.text),
                                    ),
                                    if (patientPhone != null && patientPhone.isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      Text(
                                        '($patientPhone)',
                                        style: t(12, c: C.sub),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Items summary
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: C.bg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final itm in items)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '• ${itm['name'] ?? itm['medicine_name'] ?? 'Item'}',
                                                  style: t(13, w: FontWeight.w500),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                'x${itm['quantity'] ?? 1}',
                                                style: t(12, c: C.sub, w: FontWeight.w600),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Rs. ${((itm['price'] ?? 0.0) as num).toStringAsFixed(0)}',
                                                style: t(13, w: FontWeight.w600, c: C.text),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Total & Action buttons
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total Amount', style: t(11, c: C.sub)),
                                        Text(
                                          'Rs. ${total.toStringAsFixed(0)}',
                                          style: t(16, w: FontWeight.w800, c: C.text),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),

                                    // Status specific actions
                                    if (status == 'pending' || status == 'order placed' || status == 'awaiting pharmacist verification') ...[
                                      OutlinedButton(
                                        onPressed: () => _confirmReject(id),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: C.red,
                                          side: const BorderSide(color: C.red),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _updateStatus(id, 'accepted'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: C.purple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                        child: const Text('Accept'),
                                      ),
                                    ] else if (status == 'accepted' || status == 'preparing order') ...[
                                      ElevatedButton.icon(
                                        onPressed: () => _updateStatus(id, 'ready'),
                                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                        label: const Text('Mark Ready'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: C.indigo,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ] else if (status == 'ready' || status == 'ready for pickup') ...[
                                      ElevatedButton.icon(
                                        onPressed: () => _updateStatus(id, 'completed'),
                                        icon: const Icon(Icons.done_all_rounded, size: 16),
                                        label: const Text('Complete Order'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: C.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}
