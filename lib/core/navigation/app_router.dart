import 'package:flutter/material.dart';

import '../../features/admin/presentation/admin_main_shell.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/citizen/presentation/citizen_main_shell.dart';
import '../../features/map/presentation/shared_map_view.dart';
import '../../features/notifications/presentation/shared_notifications_view.dart';
import '../../features/profile/presentation/shared_profile_view.dart';
import '../../features/reports/presentation/citizen_report_form_screen.dart';
import '../../features/reports/presentation/shared_reports_view.dart';
import '../../features/technician/presentation/technician_main_shell.dart';

/// Centralized routing configuration for AquaTrace.
class AppRouter {
  AppRouter._();

  static const String initial = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  static const String citizenHome = '/citizen';
  static const String technicianHome = '/technician';
  static const String adminHome = '/admin';

  static const String faultMap = '/map';
  static const String reportsList = '/reports';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String reportFault = '/reports/new';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );
      case forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
          settings: settings,
        );
      case citizenHome:
        return MaterialPageRoute(
          builder: (_) => const CitizenMainShell(),
          settings: settings,
        );
      case technicianHome:
        return MaterialPageRoute(
          builder: (_) => const TechnicianMainShell(),
          settings: settings,
        );
      case adminHome:
        return MaterialPageRoute(
          builder: (_) => const AdminMainShell(),
          settings: settings,
        );
      case faultMap:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: SharedMapView()),
          settings: settings,
        );
      case reportsList:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: SharedReportsView()),
          settings: settings,
        );
      case notifications:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: SharedNotificationsView()),
          settings: settings,
        );
      case profile:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: SharedProfileView()),
          settings: settings,
        );
      case reportFault:
        return MaterialPageRoute<bool>(
          builder: (_) => const CitizenReportFormScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
    }
  }
}
