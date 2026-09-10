// ShopFlow — application entry point.
//
// Boots Firebase, exposes the single [ApiService] orchestrator to the whole
// widget tree through Provider, and declares the named routes for every page.
// The app has two user personas (buyer and seller) that share the same routes;
// each screen adapts its content based on `ApiService.isSeller`.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/register_screen.dart';
import 'screens/seller_dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
  }
  runApp(const ShopFlowApp());
}

/// Root widget wiring dependency injection, theme, and routes together.
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
          '/splash': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const HomeScreen(),
          '/products': (_) => const ProductListScreen(),
          '/product-detail': (_) => const ProductDetailScreen(),
          '/cart': (_) => const CartScreen(),
          '/seller-dashboard': (_) => const SellerDashboardScreen(),
        },
      ),
    );
  }
}
