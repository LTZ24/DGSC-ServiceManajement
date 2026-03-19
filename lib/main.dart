import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'services/app_log_service.dart';
import 'services/backend_service.dart';
import 'services/diagnosis_config_service.dart';
import 'services/push_notification_service.dart';
import 'services/app_lock_service.dart';
import 'screens/app_lock/app_lock_wrapper.dart';
import 'widgets/global_refresh_wrapper.dart';
import 'auth_wrapper.dart';

// Auth screens
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';

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
import 'screens/admin/diagnosis_editor_screen.dart';
import 'screens/admin/services_screen.dart';
import 'screens/admin/customers_screen.dart';
import 'screens/admin/finance_screen.dart';
import 'screens/admin/spare_parts_screen.dart';
import 'screens/admin/counter_screen.dart';
import 'screens/admin/ppob_settings_screen.dart';
import 'screens/admin/ppob_receipt_settings_screen.dart';
import 'screens/admin/store_settings_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/admin/admin_log_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLogService.initialize();

  FlutterError.onError = (details) {
    AppLogService.logFlutterError(details);
    FlutterError.presentError(details);
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppLogService.logError(error, stack);
    return true;
  };

  runZonedGuarded(() async {
    await Firebase.initializeApp();
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://your-project.supabase.co',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'your-anon-key',
      ),
    );
    await DiagnosisConfigService.loadLocalDatasetIntoEngine();
    Future.microtask(() => DiagnosisConfigService.syncPublishedDataset());
    await initializeDateFormatting('id_ID');
    await initializeDateFormatting('en_US');
    await PushNotificationService.initialize();

    await AppLogService.log('App initialized');
    runApp(const DGSCApp());
  }, (error, stack) {
    AppLogService.logError(error, stack);
  });
}

class DGSCApp extends StatefulWidget {
  const DGSCApp({super.key});

  @override
  State<DGSCApp> createState() => _DGSCAppState();
}

class _DGSCAppState extends State<DGSCApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        await _syncPushSubscriptions();
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/reset-password',
            (route) => false,
          );
        }
      },
    );

    Future.microtask(_syncPushSubscriptions);
  }

  Future<void> _syncPushSubscriptions() async {
    final uid = BackendService.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      await PushNotificationService.syncTopicSubscriptions();
      return;
    }

    final profile = await BackendService.getUserProfile(uid);
    await PushNotificationService.syncTopicSubscriptions(
      userId: uid,
      role: profile?['role']?.toString(),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'DigiTech Service Center',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
            themeAnimationCurve: Curves.easeOutCubic,
            themeAnimationDuration: const Duration(milliseconds: 320),
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('id'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => AppLockWrapper(
              child: child ?? const SizedBox.shrink(),
            ),
            initialRoute: '/home',
            routes: {
              '/auth-wrapper': (context) => const AuthWrapper(),
              // Pre-login homepage (now initial)
              '/home': (context) => const HomeScreen(),
              // Splash (optional, kept for reference)
              '/splash': (context) => const SplashScreen(),
              // Auth
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/reset-password': (context) => const ResetPasswordScreen(),

              // Public diagnosis (accessible from home screen, no login required)
              '/diagnosis': (context) => const DiagnosisScreen(),

              // Customer
              '/customer/dashboard': (context) =>
                  const CustomerDashboardScreen(),
              '/customer/booking': (context) => const BookingScreen(),
              '/customer/diagnosis': (context) => const DiagnosisScreen(),
              '/customer/status': (context) => const StatusScreen(),
              '/customer/history': (context) => const HistoryScreen(),
              '/customer/profile': (context) => const ProfileScreen(),
              '/customer/settings': (context) => const CustomerSettingsScreen(),

              // Admin
              '/admin/dashboard': (context) => const AdminDashboardScreen(),
              '/admin/bookings': (context) => const AdminBookingsScreen(),
              '/admin/services': (context) => const AdminServicesScreen(),
              '/admin/customers': (context) => const AdminCustomersScreen(),
              '/admin/finance': (context) => const AdminFinanceScreen(),
              '/admin/spare-parts': (context) => const AdminSparePartsScreen(),
              '/admin/counter': (context) => const AdminCounterScreen(),
                '/admin/ppob-settings': (context) => const PpobSettingsScreen(),
                '/admin/ppob-receipt-settings': (context) =>
                  const PpobReceiptSettingsScreen(),
              '/admin/store-settings': (context) => const StoreSettingsScreen(),
              '/admin/diagnosis-editor': (context) =>
                  const AdminDiagnosisEditorScreen(),
              '/admin/settings': (context) => const AdminSettingsScreen(),
              '/admin/logs': (context) => const AdminLogScreen(),
            },
          );
        },
      ),
    );
  }
}
