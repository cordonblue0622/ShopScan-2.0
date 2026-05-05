import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/auth_provider.dart';
import 'core/utils/cart_provider.dart';
import 'screens/login_screen.dart';
import 'screens/shop_registration_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/cashier_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: !kIsWeb,
    sslEnabled: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'ShopScan',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          if (settings.name == '/register-shop') {
            return MaterialPageRoute(
              builder: (context) => const ShopRegistrationScreen(),
            );
          }
          return null;
        },
      ),
    );
  }
}

/// Wrapper that handles authentication state and navigation
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Not authenticated
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        // Authenticated as owner
        if (authProvider.isOwner) {
          return const OwnerDashboardScreen();
        }

        // Authenticated as cashier
        if (authProvider.isCashier) {
          return const CashierDashboardScreen();
        }

        // Default fallback
        return const LoginScreen();
      },
    );
  }
}
