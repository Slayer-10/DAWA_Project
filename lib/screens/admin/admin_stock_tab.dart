import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminStockTab extends StatefulWidget {
  const AdminStockTab({super.key});

  @override
  State<AdminStockTab> createState() => _AdminStockTabState();
}

class _AdminStockTabState extends State<AdminStockTab> {
  List<Map<String, dynamic>> _stocks = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  static const List<String> _medicineForms = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Suspension',
    'Injection',
    'Drops',
    'Ointment',
    'Cream',
    'Inhaler',
    'Gel',
  ];

  @override
  void initState() {
    super.initState();
    _fetchStock();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStock() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.instance.getAdminStock();
      if (!mounted) return;
      setState(() {
        _stocks = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStocks {
    if (_searchQuery.trim().isEmpty) return _stocks;
    final q = _searchQuery.trim().toLowerCase();
    return _stocks.where((s) {
      final name = (s['medicine_name'] ?? '').toString().toLowerCase();
      final str = (s['strength'] ?? '').toString().toLowerCase();
      final form = (s['form'] ?? '').toString().toLowerCase();
      return name.contains(q) || str.contains(q) || form.contains(q);
    }).toList();
  }

  void _openStockSheet({Map<String, dynamic>? item}) {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?['medicine_name'] ?? '');
    final strengthCtrl = TextEditingController(text: item?['strength'] ?? '');
    String selectedForm = item?['form'] ?? 'Tablet';
    if (!_medicineForms.contains(selectedForm)) selectedForm = 'Tablet';
    final priceCtrl = TextEditingController(
      text: item != null ? ((item['price'] ?? 0.0) as num).toString() : '',
    );
    final qtyCtrl = TextEditingController(
      text: item != null ? (item['quantity'] ?? 0).toString() : '',
    );

    String? sheetError;
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        isEdit ? 'Edit Medicine' : 'Add New Medicine',
                        style: t(18, w: FontWeight.w800, c: C.text),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (sheetError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: C.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        sheetError!,
                        style: t(12, c: C.red, w: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Medicine Name
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Medicine Name',
                      hintText: 'e.g. Paracetamol',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Strength & Form
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: strengthCtrl,
                          decoration: InputDecoration(
                            labelText: 'Strength',
                            hintText: 'e.g. 500mg',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedForm,
                          decoration: InputDecoration(
                            labelText: 'Form',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _medicineForms
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setSheetState(() => selectedForm = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Price & Quantity
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Unit Price (PKR)',
                            hintText: 'e.g. 50',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Stock Quantity',
                            hintText: 'e.g. 100',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final strength = strengthCtrl.text.trim();
                            final price = double.tryParse(priceCtrl.text.trim());
                            final qty = int.tryParse(qtyCtrl.text.trim());

                            if (name.isEmpty) {
                              setSheetState(() => sheetError = 'Medicine name is required');
                              return;
                            }
                            if (price == null || price < 0) {
                              setSheetState(() => sheetError = 'Valid price is required');
                              return;
                            }
                            if (qty == null || qty < 0) {
                              setSheetState(() => sheetError = 'Valid quantity is required');
                              return;
                            }

                            setSheetState(() {
                              sheetError = null;
                              saving = true;
                            });

                            if (isEdit) {
                              final id = item['id'] as int;
                              final updated = await ApiService.instance.updateAdminStock(
                                id,
                                medicineName: name,
                                strength: strength.isNotEmpty ? strength : null,
                                form: selectedForm,
                                price: price,
                                quantity: qty,
                              );
                              if (updated != null) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) _fetchStock();
                              } else {
                                setSheetState(() {
                                  sheetError = 'Failed to update medicine stock';
                                  saving = false;
                                });
                              }
                            } else {
                              final created = await ApiService.instance.createAdminStock(
                                medicineName: name,
                                strength: strength.isNotEmpty ? strength : null,
                                form: selectedForm,
                                price: price,
                                quantity: qty,
                              );
                              if (created != null) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) _fetchStock();
                              } else {
                                setSheetState(() {
                                  sheetError = 'Failed to add medicine to stock';
                                  saving = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEdit ? 'Save Changes' : 'Add to Stock',
                            style: t(15, w: FontWeight.w700, c: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(int stockId, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Stock Item', style: t(17, w: FontWeight.w700, c: C.danger)),
        content: Text('Are you sure you want to delete "$name" from your pharmacy stock?', style: t(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: t(14, c: C.sub)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.instance.deleteAdminStock(stockId);
              if (ok) {
                _fetchStock();
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete item')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: C.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openStockSheet(),
        backgroundColor: C.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Medicine'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search medicines by name, strength...',
                hintStyle: t(14, c: C.sub),
                prefixIcon: const Icon(Icons.search_rounded, color: C.sub),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          ),

          // Stock Items List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchStock,
              color: C.purple,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: C.purple))
                  : _filteredStocks.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            EmptyState(
                              Icons.inventory_2_outlined,
                              'No Stock Items',
                              'Tap "+ Add Medicine" below to add pharmaceutical inventory.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _filteredStocks.length,
                          itemBuilder: (ctx, i) {
                            final s = _filteredStocks[i];
                            final id = s['id'] as int;
                            final name = s['medicine_name'] ?? 'Medicine';
                            final strength = s['strength'] as String?;
                            final form = s['form'] as String? ?? 'Tablet';
                            final price = (s['price'] ?? 0.0) as num;
                            final qty = (s['quantity'] ?? 0) as int;

                            // Badge styling
                            final Color badgeBg;
                            final Color badgeText;
                            final String badgeLabel;

                            if (qty == 0) {
                              badgeBg = C.red.withValues(alpha: 0.12);
                              badgeText = C.red;
                              badgeLabel = 'Out of Stock';
                            } else if (qty <= 5) {
                              badgeBg = C.amber.withValues(alpha: 0.12);
                              badgeText = C.amber;
                              badgeLabel = 'Low Stock ($qty left)';
                            } else {
                              badgeBg = C.green.withValues(alpha: 0.12);
                              badgeText = C.green;
                              badgeLabel = 'In Stock ($qty)';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: C.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: C.light,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.medication_rounded, color: C.purple, size: 24),
                                  ),
                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: t(15, w: FontWeight.w700, c: C.text),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: badgeBg,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                badgeLabel,
                                                style: t(11, w: FontWeight.w700, c: badgeText),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${strength != null && strength.isNotEmpty ? "$strength • " : ""}$form',
                                          style: t(12, c: C.sub),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rs. ${price.toStringAsFixed(0)}',
                                          style: t(14, w: FontWeight.w800, c: C.purple),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Edit & Delete Actions
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: C.sub),
                                    tooltip: 'Edit item',
                                    onPressed: () => _openStockSheet(item: s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: C.red),
                                    tooltip: 'Delete item',
                                    onPressed: () => _confirmDelete(id, name),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
