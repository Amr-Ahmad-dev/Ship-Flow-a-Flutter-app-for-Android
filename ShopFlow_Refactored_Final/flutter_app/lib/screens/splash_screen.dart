// lib/screens/splash_screen.dart
// ★ FIRST SCREEN ★  Shown while the app checks for a saved JWT.
// Routes to /home if already logged in, /login otherwise.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // The initState function sets up the splash screen's initial logic.
  // It uses addPostFrameCallback to ensure the widget tree is fully built 
  // before attempting any navigation or state-heavy operations.
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so the widget tree is built before we navigate.
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  // The _route function handles the app's initial routing logic.
  // It introduces a short delay to allow the ApiService's auth state to stabilize.
  // PURPOSE: It directs authenticated users to the Home screen and unauthenticated users to the Login screen.
  // EDGE CASE: If the device is offline, the auth check might take longer than the 600ms delay, 
  // potentially causing a flicker or a race condition with the login state.
  Future<void> _route() async {
    // Give ApiService.init() time to finish restoring the JWT.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final api = context.read<ApiService>();
    if (api.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // The build method renders a simple branded splash screen with a loading indicator.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.kPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ShopFlow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
