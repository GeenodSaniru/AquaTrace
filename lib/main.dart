import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_roles.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/navigation_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/data_repository.dart';
import 'core/services/firebase_service.dart';
import 'core/services/preferences_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/admin/presentation/admin_main_shell.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/citizen/presentation/citizen_main_shell.dart';
import 'features/technician/presentation/technician_main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize environment-safe Firebase service (graceful fallback if credentials missing)
  await FirebaseService.initialize();

  // Initialize persistent preferences
  final prefsService = await PreferencesService.create();

  // Initialize Core Services
  final authService = AuthService(prefsService);
  final themeProvider = ThemeProvider();
  final dataRepository = DataRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider<PreferencesService>.value(value: prefsService),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider.value(value: dataRepository),
      ],
      child: const AquaTraceApp(),
    ),
  );
}

/// Root widget for AquaTrace.
class AquaTraceApp extends StatelessWidget {
  const AquaTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      navigatorKey: NavigationService.navigatorKey,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const RoleGate(),
      builder: (context, child) {
        final preferences = context.watch<PreferencesService>();
        final baseTheme = themeProvider.isDarkMode
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        final isDark = themeProvider.isDarkMode;
        final content = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(preferences.textScaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );

        if (!preferences.highContrastMode) return content;
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: isDark ? Colors.cyanAccent : Colors.blue.shade900,
              onSurface: isDark ? Colors.white : Colors.black,
              secondary: isDark ? Colors.cyanAccent : Colors.blue.shade900,
            ),
            dividerTheme: baseTheme.dividerTheme.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
              thickness: 1.5,
            ),
            textTheme: baseTheme.textTheme.apply(
              bodyColor: isDark ? Colors.white : Colors.black,
              displayColor: isDark ? Colors.white : Colors.black,
            ),
          ),
          child: content,
        );
      },
    );
  }
}

/// Dynamic gate directing authenticated users to their assigned role interface.
class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    switch (authProvider.currentRole) {
      case UserRole.citizen:
        return const CitizenMainShell();
      case UserRole.technician:
        return const TechnicianMainShell();
      case UserRole.admin:
        return const AdminMainShell();
    }
  }
}
