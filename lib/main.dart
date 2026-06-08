import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart';
import 'product_provider.dart';
import 'staff_provider.dart';
import 'billing_provider.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/products_screen.dart';
import 'screens/staff_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/ledger_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => StaffProvider()),
        ChangeNotifierProvider(create: (_) => BillingProvider()),
      ],
      child: const VighnahartaApp(),
    ),
  );
}

class VighnahartaApp extends StatelessWidget {
  const VighnahartaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return MaterialApp(
      title: 'Vighnaharta Fataka',
      theme: AppTheme.lightTheme,
      home: authProvider.isAuthenticated 
          ? const DashboardScreen() 
          : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/inventory': (context) => const ProductsScreen(),
        '/staff': (context) => const StaffScreen(),
        '/billing': (context) => const BillingScreen(),
        '/ledger': (context) => const LedgerScreen(),
      },
    );
  }
}
