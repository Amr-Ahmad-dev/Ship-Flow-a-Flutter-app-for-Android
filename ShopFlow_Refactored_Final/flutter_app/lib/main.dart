// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/home_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/seller_dashboard_screen.dart';

/// Entry point for the ShopFlow Flutter application.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  runApp(const ShopFlowApp());
}

/// Root widget that wires dependency injection, theme, and app routes together.
class ShopFlowApp extends StatelessWidget {
  const ShopFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ApiService()..init(),
      child: MaterialApp(
        title: 'ShopFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.buildTheme(),
        initialRoute: '/splash',
        routes: {
          '/splash':            (_) => const SplashScreen(),
          '/login':             (_) => const LoginScreen(),
          '/register':          (_) => const RegisterScreen(),
          '/verify-email':      (_) => const VerifyEmailScreen(),
          '/home':              (_) => const HomeScreen(),
          '/products':          (_) => const ProductListScreen(),
          '/product-detail':    (_) => const ProductDetailScreen(),
          '/cart':              (_) => const CartScreen(),
          '/seller-dashboard':  (_) => const SellerDashboardScreen(),
        },
      ),
    );
  }
}
