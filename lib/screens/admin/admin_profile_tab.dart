import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_state.dart';
import '../../services/location_state.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';

class AdminProfileTab extends StatefulWidget {
  const AdminProfileTab({super.key});

  @override
  State<AdminProfileTab> createState() => _AdminProfileTabState();
}

class _AdminProfileTabState extends State<AdminProfileTab> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();

  bool _isOpen = true;
  double? _lat;
  double? _lng;
  bool _saving = false;
  String? _message;
  bool _isSuccessMessage = true;

  @override
  void initState() {
    super.initState();
    _loadPharmacyData();
  }

  void _loadPharmacyData() {
    final ph = AuthState.instance.pharmacy;
    if (ph != null) {
      _nameCtrl.text = ph.name;
      _addressCtrl.text = ph.address;
      _phoneCtrl.text = ph.phone ?? '';
      _hoursCtrl.text = ph.openingHours ?? '9:00 AM – 11:00 PM';
      _isOpen = ph.isOpen;
      _lat = ph.lat;
      _lng = ph.lng;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleOpen(bool val) async {
    setState(() => _isOpen = val);
    try {
      final updated = await ApiService.instance.updatePharmacyProfile(isOpen: val);
      if (updated != null) {
        await AuthState.instance.init();
      }
    } catch (_) {}
  }

  Future<void> _pickLocation() async {
    await showLocationPickerSheet(context);
    if (!mounted) return;
    final loc = LocationState.instance;
    if (loc.lat != null && loc.lng != null) {
      setState(() {
        _lat = loc.lat;
        _lng = loc.lng;
        if (loc.label.isNotEmpty) {
          _addressCtrl.text = loc.label;
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final hours = _hoursCtrl.text.trim();

    if (name.isEmpty) {
      setState(() {
        _message = 'Pharmacy name cannot be empty';
        _isSuccessMessage = false;
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final updated = await ApiService.instance.updatePharmacyProfile(
        name: name,
        address: address,
        lat: _lat,
        lng: _lng,
        phone: phone.isNotEmpty ? phone : null,
        openingHours: hours.isNotEmpty ? hours : null,
        isOpen: _isOpen,
      );

      if (!mounted) return;
      setState(() => _saving = false);

      if (updated != null) {
        await AuthState.instance.init();
        if (!mounted) return;
        setState(() {
          _message = 'Pharmacy profile updated successfully';
          _isSuccessMessage = true;
        });
      } else {
        setState(() {
          _message = 'Failed to update pharmacy profile';
          _isSuccessMessage = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Error: $e';
        _isSuccessMessage = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthState.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthState.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pharmacy Header Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [C.indigo, C.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: C.purple.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.local_pharmacy_rounded, color: C.purple, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'My Pharmacy',
                            style: t(18, w: FontWeight.w800, c: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Admin: ${auth.user?.name ?? "Administrator"}',
                            style: t(12, c: const Color(0xFFDDD6FE)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Open / Closed Switch Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _isOpen ? C.green : C.sub,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOpen ? 'Pharmacy is Open' : 'Pharmacy is Closed',
                            style: t(15, w: FontWeight.w700, c: C.text),
                          ),
                          Text(
                            _isOpen
                                ? 'Accepting patient orders live'
                                : 'Temporarily paused for incoming orders',
                            style: t(12, c: C.sub),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isOpen,
                      activeThumbColor: C.green,
                      onChanged: _toggleOpen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Profile Form Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.border),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Pharmacy Details', style: t(16, w: FontWeight.w700, c: C.text)),
                    const SizedBox(height: 16),

                    if (_message != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_isSuccessMessage ? C.green : C.red).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_isSuccessMessage ? C.green : C.red).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _message!,
                          style: t(13, w: FontWeight.w600, c: _isSuccessMessage ? C.green : C.red),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildField(controller: _nameCtrl, label: 'Pharmacy Name', icon: Icons.storefront_rounded),
                    const SizedBox(height: 14),

                    _buildField(controller: _addressCtrl, label: 'Street Address', icon: Icons.location_on_outlined),
                    const SizedBox(height: 10),

                    // Change Location button
                    OutlinedButton.icon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: Text(
                        _lat != null
                            ? 'Location: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)} (Change)'
                            : 'Set GPS Location',
                        style: t(13, w: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.purple,
                        side: const BorderSide(color: C.purple),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildField(
                      controller: _phoneCtrl,
                      label: 'Contact Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),

                    _buildField(
                      controller: _hoursCtrl,
                      label: 'Operating Hours',
                      icon: Icons.access_time_rounded,
                      hint: 'e.g. 9:00 AM – 11:00 PM',
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Save Profile Updates', style: t(15, w: FontWeight.w700, c: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Log Out Button
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out of Pharmacy Admin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: C.red,
                  elevation: 0,
                  side: const BorderSide(color: C.red),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t(12, w: FontWeight.w600, c: C.text)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: t(14, c: C.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t(14, c: C.sub),
            prefixIcon: Icon(icon, size: 20, color: C.sub),
            filled: true,
            fillColor: C.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.purple, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
