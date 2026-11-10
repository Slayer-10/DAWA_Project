import 'package:flutter/material.dart';
import '../../services/auth_state.dart';
import '../../theme/app_theme.dart';
import '../shell.dart';
import '../auth/login_screen.dart';
import 'admin_orders_tab.dart';
import 'admin_stock_tab.dart';
import 'admin_profile_tab.dart';

class PharmacyAdminShell extends StatefulWidget {
  const PharmacyAdminShell({super.key});

  @override
  State<PharmacyAdminShell> createState() => _PharmacyAdminShellState();
}

class _PharmacyAdminShellState extends State<PharmacyAdminShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    AdminOrdersTab(),
    AdminStockTab(),
    AdminProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Route guard: If user is not pharmacy_admin, navigate away
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRoleGuard();
    });
  }

  void _checkRoleGuard() {
    final auth = AuthState.instance;
    if (!auth.isAuthenticated) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else if (!auth.isPharmacyAdmin) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    }
  }

  String get _appBarTitle {
    switch (_currentIndex) {
      case 0:
        return 'Orders Dashboard';
      case 1:
        return 'Stock Inventory';
      case 2:
        return 'Pharmacy Profile';
      default:
        return 'Admin Portal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthState.instance;
    final pharmacy = auth.pharmacy;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _appBarTitle,
              style: t(17, w: FontWeight.w800, c: C.text),
            ),
            Text(
              pharmacy?.name.isNotEmpty == true
                  ? pharmacy!.name
                  : (auth.user?.name ?? 'DAWA Partner Pharmacy'),
              style: t(12, c: C.sub),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: C.red),
            tooltip: 'Log Out',
            onPressed: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: C.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          indicatorColor: C.light,
          elevation: 0,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: C.purple),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded, color: C.purple),
              label: 'Stock',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded, color: C.purple),
              label: 'Pharmacy',
            ),
          ],
        ),
      ),
    );
  }
}
