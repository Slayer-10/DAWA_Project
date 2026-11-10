import 'package:flutter/material.dart';
import '../../services/auth_state.dart';
import '../../services/location_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dawa_brand_mark.dart';
import '../shell.dart';
import '../admin/admin_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Role: 'patient' or 'pharmacy_admin'
  String _selectedRole = 'patient';

  // Form controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Pharmacy specific controllers
  final _pharmacyNameCtrl = TextEditingController();
  final _pharmacyAddressCtrl = TextEditingController();
  double? _pharmacyLat;
  double? _pharmacyLng;

  bool _obscurePassword = true;
  String? _localError;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _localError = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pharmacyNameCtrl.dispose();
    _pharmacyAddressCtrl.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final regExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regExp.hasMatch(email);
  }

  Future<void> _submitLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || !_validateEmail(email)) {
      setState(() => _localError = 'Please enter a valid email address');
      return;
    }
    if (password.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _localError = null;
      _loading = true;
    });

    final success = await AuthState.instance.login(email, password);
    if (!mounted) return;

    setState(() => _loading = false);

    if (success) {
      _navigateToHome();
    } else {
      setState(() {
        _localError = AuthState.instance.error ?? 'Invalid credentials';
      });
    }
  }

  Future<void> _submitRegister() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _localError = 'Please enter your name');
      return;
    }
    if (email.isEmpty || !_validateEmail(email)) {
      setState(() => _localError = 'Please enter a valid email address');
      return;
    }
    if (password.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters');
      return;
    }

    Map<String, dynamic>? pharmacyData;
    if (_selectedRole == 'pharmacy_admin') {
      final phName = _pharmacyNameCtrl.text.trim();
      final phAddress = _pharmacyAddressCtrl.text.trim();
      if (phName.isEmpty) {
        setState(() => _localError = 'Please enter pharmacy name');
        return;
      }
      if (phAddress.isEmpty) {
        setState(() => _localError = 'Please enter pharmacy address');
        return;
      }
      final lat = _pharmacyLat ?? LocationState.instance.lat;
      final lng = _pharmacyLng ?? LocationState.instance.lng;
      if (lat == null || lng == null) {
        setState(() => _localError = 'Please set pharmacy location on the map');
        return;
      }
      pharmacyData = {
        'name': phName,
        'address': phAddress,
        'lat': lat,
        'lng': lng,
        'phone': phone.isNotEmpty ? phone : null,
      };
    }

    setState(() {
      _localError = null;
      _loading = true;
    });

    final success = await AuthState.instance.register(
      name: name,
      email: email,
      password: password,
      role: _selectedRole,
      phone: phone.isNotEmpty ? phone : null,
      pharmacy: pharmacyData,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      _navigateToHome();
    } else {
      setState(() {
        _localError = AuthState.instance.error ?? 'Registration failed';
      });
    }
  }

  void _navigateToHome() {
    final role = AuthState.instance.role;
    final targetScreen = (role == 'pharmacy_admin')
        ? const PharmacyAdminShell()
        : const AppShell();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => targetScreen),
      (route) => false,
    );
  }

  Future<void> _pickPharmacyLocation() async {
    await showLocationPickerSheet(context);
    if (!mounted) return;
    final loc = LocationState.instance;
    if (loc.lat != null && loc.lng != null) {
      setState(() {
        _pharmacyLat = loc.lat;
        _pharmacyLng = loc.lng;
        if (loc.label.isNotEmpty) {
          _pharmacyAddressCtrl.text = loc.label;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Brand Mark
                  Center(
                    child: Column(
                      children: [
                        const DawaBrandMark(size: 80),
                        const SizedBox(height: 14),
                        Text(
                          'DAWA',
                          style: t(28, w: FontWeight.w900, c: C.primary),
                        ),
                        Text(
                          'Verified Healthcare & Pharmacy Network',
                          style: t(13, c: C.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Segmented Role Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: C.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = 'patient'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'patient' ? C.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: _selectedRole == 'patient' ? Colors.white : C.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Patient',
                                    style: t(14, w: FontWeight.w700, c: _selectedRole == 'patient' ? Colors.white : C.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = 'pharmacy_admin'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'pharmacy_admin' ? C.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_pharmacy_rounded,
                                    size: 18,
                                    color: _selectedRole == 'pharmacy_admin' ? Colors.white : C.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pharmacy',
                                    style: t(14, w: FontWeight.w700, c: _selectedRole == 'pharmacy_admin' ? Colors.white : C.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Card with TabBar & Forms
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: C.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Login / Sign Up Tabs
                        TabBar(
                          controller: _tabController,
                          labelColor: C.primary,
                          unselectedLabelColor: C.textSecondary,
                          indicatorColor: C.primary,
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.label,
                          labelStyle: t(15, w: FontWeight.w700),
                          unselectedLabelStyle: t(15, w: FontWeight.w500),
                          tabs: const [
                            Tab(text: 'Sign In'),
                            Tab(text: 'Create Account'),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Inline Error Banner
                        if (_localError != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: C.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: C.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: C.danger, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _localError!,
                                    style: t(13, c: C.danger, w: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Form Fields
                        AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, _) {
                            final isRegister = _tabController.index == 1;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isRegister) ...[
                                  _buildTextField(
                                    controller: _nameCtrl,
                                    label: 'Full Name',
                                    hint: 'e.g. Dr. Ahmed Khan',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                _buildTextField(
                                  controller: _emailCtrl,
                                  label: 'Email Address',
                                  hint: 'you@domain.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),

                                _buildTextField(
                                  controller: _passwordCtrl,
                                  label: 'Password',
                                  hint: 'Min. 8 characters',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 20,
                                      color: C.textSecondary,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                if (isRegister) ...[
                                  _buildTextField(
                                    controller: _phoneCtrl,
                                    label: 'Phone Number (Optional)',
                                    hint: '+92 300 1234567',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 14),

                                  if (_selectedRole == 'pharmacy_admin') ...[
                                    const Divider(height: 24),
                                    Text(
                                      'Pharmacy Details',
                                      style: t(14, w: FontWeight.w700, c: C.primary),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _pharmacyNameCtrl,
                                      label: 'Pharmacy Name',
                                      hint: 'e.g. Al-Shifa Care Pharmacy',
                                      icon: Icons.local_pharmacy_outlined,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildTextField(
                                      controller: _pharmacyAddressCtrl,
                                      label: 'Pharmacy Address',
                                      hint: 'Street, Sector, City',
                                      icon: Icons.location_on_outlined,
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      onPressed: _pickPharmacyLocation,
                                      icon: const Icon(Icons.my_location_rounded, size: 18),
                                      label: Text(
                                        _pharmacyLat != null
                                            ? 'Location Set (${_pharmacyLat!.toStringAsFixed(3)}, ${_pharmacyLng!.toStringAsFixed(3)})'
                                            : 'Set Pharmacy Location (GPS / Map)',
                                        style: t(13, w: FontWeight.w600),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: C.primary,
                                        side: const BorderSide(color: C.primary),
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                ],

                                const SizedBox(height: 8),

                                // Submit Button
                                ElevatedButton(
                                  onPressed: _loading ? null : (isRegister ? _submitRegister : _submitLogin),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: C.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          isRegister
                                              ? (_selectedRole == 'pharmacy_admin' ? 'Register Pharmacy' : 'Sign Up as Patient')
                                              : 'Sign In',
                                          style: t(15, w: FontWeight.w700, c: Colors.white),
                                        ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t(12, w: FontWeight.w600, c: C.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: t(14, c: C.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t(14, c: C.textSecondary.withValues(alpha: 0.6)),
            prefixIcon: Icon(icon, size: 20, color: C.textSecondary),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: C.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
