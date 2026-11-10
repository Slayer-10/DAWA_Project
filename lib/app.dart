import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/auth_state.dart';
import 'theme/app_theme.dart';

class DawaApp extends StatefulWidget {
  const DawaApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<DawaApp> createState() => _DawaAppState();
}

class _DawaAppState extends State<DawaApp> {
  @override
  void initState() {
    super.initState();
    AuthState.instance.onAuthRequired = () {
      DawaApp.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: DawaApp.navigatorKey,
      title: 'DAWA',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const WelcomeScreen(),
    );
  }
}
