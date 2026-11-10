import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../design/design.dart';
import '../services/auth_state.dart';
import 'admin/admin_shell.dart';
import 'auth/login_screen.dart';
import 'home_screen.dart';
import 'other_screens.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPatientRoleGuard();
    });
  }

  void _checkPatientRoleGuard() {
    final auth = AuthState.instance;
    if (!auth.isAuthenticated) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else if (auth.isPharmacyAdmin) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PharmacyAdminShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (context, index, _) {
        return Scaffold(
          backgroundColor: DawaColors.background,
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: IndexedStack(
                  index: index,
                  children: const [
                    HomeScreen(),
                    ExploreScreen(),
                    OrdersScreen(),
                    ProfileScreen(embedded: true),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: DawaFloatingNavBar(
            currentIndex: index,
            items: _items,
            onTap: (newIndex) => tabIndex.value = newIndex,
          ),
        );
      },
    );
  }
}
