import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
// Uncomment after running `flutterfire configure`:
import 'firebase_options.dart';

// Auth screens
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

// Customer screens
import 'screens/customer/customer_dashboard.dart' show CustomerDashboardScreen;
import 'screens/customer/booking_screen.dart';
import 'screens/customer/diagnosis_screen.dart' show DiagnosisScreen;
import 'screens/customer/status_screen.dart';
import 'screens/customer/history_screen.dart';
import 'screens/customer/profile_screen.dart';
import 'screens/customer/settings_screen.dart';

// Admin screens
import 'screens/admin/admin_dashboard.dart' show AdminDashboardScreen;
import 'screens/admin/bookings_screen.dart';
import 'screens/admin/services_screen.dart';
import 'screens/admin/customers_screen.dart';
import 'screens/admin/finance_screen.dart';
import 'screens/admin/spare_parts_screen.dart';
import 'screens/admin/counter_screen.dart';
import 'screens/admin/store_settings_screen.dart';
import 'screens/admin/admin_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DGSCApp());
}

class DGSCApp extends StatelessWidget {
  const DGSCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'DigiTech Service Center',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/home',
            routes: {
              // Pre-login homepage (now initial)
              '/home': (context) => const HomeScreen(),
              // Splash (optional, kept for reference)
              '/splash': (context) => const SplashScreen(),
              // Auth
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),

              // Public diagnosis (accessible from home screen, no login required)
              '/diagnosis': (context) => const DiagnosisScreen(),

              // Customer
              '/customer/dashboard': (context) => const CustomerDashboardScreen(),
              '/customer/booking': (context) => const BookingScreen(),
              '/customer/diagnosis': (context) =>
                  const DiagnosisScreen(),
              '/customer/status': (context) => const StatusScreen(),
              '/customer/history': (context) => const HistoryScreen(),
              '/customer/profile': (context) => const ProfileScreen(),
              '/customer/settings': (context) =>
                  const CustomerSettingsScreen(),

              // Admin
              '/admin/dashboard': (context) => const AdminDashboardScreen(),
              '/admin/bookings': (context) => const AdminBookingsScreen(),
              '/admin/services': (context) => const AdminServicesScreen(),
              '/admin/customers': (context) => const AdminCustomersScreen(),
              '/admin/finance': (context) => const AdminFinanceScreen(),
              '/admin/spare-parts': (context) =>
                  const AdminSparePartsScreen(),
              '/admin/counter': (context) => const AdminCounterScreen(),
              '/admin/store-settings': (context) =>
                  const StoreSettingsScreen(),
              '/admin/settings': (context) => const AdminSettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
