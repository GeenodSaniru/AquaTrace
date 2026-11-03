import 'package:aquatrace/core/config/firebase_options.dart';
import 'package:aquatrace/core/constants/app_roles.dart';
import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/models/mock_data.dart';
import 'package:aquatrace/core/models/report_model.dart';
import 'package:aquatrace/core/models/user_model.dart';
import 'package:aquatrace/core/services/auth_service.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/core/services/preferences_service.dart';
import 'package:aquatrace/core/theme/theme_provider.dart';
import 'package:aquatrace/features/auth/presentation/login_screen.dart';
import 'package:aquatrace/features/auth/presentation/register_screen.dart';
import 'package:aquatrace/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AquaTrace Foundation & Model Tests', () {
    test('UserRole enum parses and maps correctly', () {
      expect(UserRole.fromString('citizen'), UserRole.citizen);
      expect(UserRole.fromString('technician'), UserRole.technician);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('unknown'), UserRole.citizen);
    });

    test('FaultStatus and FaultSeverity enum conversions', () {
      expect(FaultStatus.fromString('pending'), FaultStatus.pending);
      expect(FaultStatus.fromString('ongoing'), FaultStatus.ongoing);
      expect(FaultStatus.fromString('completed'), FaultStatus.completed);
      expect(FaultStatus.fromString('disputed'), FaultStatus.disputed);
      expect(FaultStatus.fromString('assigned'), FaultStatus.assigned);

      expect(FaultSeverity.fromString('critical'), FaultSeverity.critical);
      expect(FaultSeverity.fromString('high'), FaultSeverity.high);
      expect(FaultSeverity.fromString('medium'), FaultSeverity.medium);
      expect(FaultSeverity.fromString('low'), FaultSeverity.low);
    });

    test('UserModel serialization and deserialization', () {
      final user = MockData.citizenUser;
      final map = user.toMap();
      final reconstructed = UserModel.fromMap(map);

      expect(reconstructed.uid, user.uid);
      expect(reconstructed.email, user.email);
      expect(reconstructed.role, user.role);
      expect(reconstructed.displayName, user.displayName);
    });

    test('ReportModel serialization and deserialization', () {
      final report = MockData.initialReports.first;
      final map = report.toMap();
      final reconstructed = ReportModel.fromMap(map);

      expect(reconstructed.reportId, report.reportId);
      expect(reconstructed.faultType, report.faultType);
      expect(reconstructed.status, report.status);
      expect(reconstructed.severity, report.severity);
      expect(reconstructed.latitude, report.latitude);
    });

    test('DataRepository initializes with MockData and filters accurately', () {
      final repo = DataRepository();
      expect(repo.reports.length, MockData.initialReports.length);
      expect(repo.notifications.length, MockData.initialNotifications.length);

      final citizenReports = repo.getReportsForCitizen(
        MockData.citizenUser.uid,
      );
      expect(citizenReports.isNotEmpty, true);

      final pending = repo.getReportsByStatus(FaultStatus.pending);
      expect(pending.any((r) => r.status == FaultStatus.pending), true);
    });
  });

  group('AquaTrace Widget & Navigation Tests', () {
    testWidgets('Login screen renders with title, fields, and demo buttons', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final prefsService = PreferencesService(prefs);
      final authService = AuthService(prefsService);
      final authProvider = AuthProvider(authService);
      final themeProvider = ThemeProvider();
      final dataRepo = DataRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            Provider<PreferencesService>.value(value: prefsService),
            Provider<AuthService>.value(value: authService),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: dataRepo),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to continue to AquaTrace'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('demo role access'), findsOneWidget);
      expect(find.text('Demo Citizen'), findsOneWidget);
      expect(find.text('Demo Technician'), findsOneWidget);
      expect(find.text('Demo Admin'), findsOneWidget);
    });

    testWidgets('Demo role selection triggers auth state change', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final prefsService = PreferencesService(prefs);
      final authService = AuthService(prefsService);
      final authProvider = AuthProvider(authService);
      final themeProvider = ThemeProvider();
      final dataRepo = DataRepository();

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            Provider<PreferencesService>.value(value: prefsService),
            Provider<AuthService>.value(value: authService),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: dataRepo),
          ],
          child: MaterialApp(
            home: const LoginScreen(),
            // Stub role routes so this auth test does not mount role shells.
            onGenerateRoute: (settings) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) =>
                    const Scaffold(body: Center(child: Text('route-stub'))),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final demoTechnician = find.text('Demo Technician');
      expect(demoTechnician, findsOneWidget);
      // Prefer ensureVisible: scrollUntilVisible(find.byType(Scrollable)) can
      // fail when more than one Scrollable exists in the tree.
      await tester.ensureVisible(demoTechnician);
      await tester.pumpAndSettle();

      // Tap on Demo Technician
      await tester.tap(demoTechnician);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(authProvider.currentRole, UserRole.technician);
      expect(authProvider.currentUser?.displayName, 'Kasun Jayawardena');
      expect(find.text('route-stub'), findsOneWidget);
    });
  });

  group('Firebase configuration', () {
    test(
      'DefaultFirebaseOptions targets AquaTrace project aquatrace-92e2e',
      () {
        expect(DefaultFirebaseOptions.isConfigured, isTrue);
        expect(DefaultFirebaseOptions.android.projectId, 'aquatrace-92e2e');
        expect(DefaultFirebaseOptions.ios.projectId, 'aquatrace-92e2e');
        expect(DefaultFirebaseOptions.web.projectId, 'aquatrace-92e2e');
        expect(DefaultFirebaseOptions.macos.projectId, 'aquatrace-92e2e');
        expect(
          DefaultFirebaseOptions.android.appId,
          '1:298509402653:android:db2fc54fac90b6b5b47cf4',
        );
        expect(
          DefaultFirebaseOptions.ios.appId,
          '1:298509402653:ios:e62995a1bb869e46b47cf4',
        );
        expect(
          DefaultFirebaseOptions.web.appId,
          '1:298509402653:web:cca7d1291ccb34d9b47cf4',
        );
      },
    );
  });

  group('Auth security (Member 1B)', () {
    test('Public registration always creates a citizen role', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService(PreferencesService(prefs));

      final user = await authService.registerWithEmailAndPassword(
        email: 'new.citizen@example.com',
        password: 'secret12',
        displayName: 'New Citizen',
        phoneNumber: '+94 77 000 1111',
        assignedArea: 'Colombo 05',
      );

      expect(user.role, UserRole.citizen);
      expect(user.email, 'new.citizen@example.com');
      expect(authService.currentUser?.role, UserRole.citizen);
    });

    testWidgets('Register screen has no privileged role picker', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final prefsService = PreferencesService(prefs);
      final authService = AuthService(prefsService);
      final authProvider = AuthProvider(authService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            Provider<PreferencesService>.value(value: prefsService),
            Provider<AuthService>.value(value: authService),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => DataRepository()),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Join AquaTrace'), findsOneWidget);
      expect(find.text('Create Citizen Account'), findsOneWidget);
      expect(find.text('Select Account Role'), findsNothing);
      // Privileged role ChoiceChips removed (copy may still mention staff roles).
      expect(find.widgetWithText(ChoiceChip, 'Citizen'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Technician'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Admin'), findsNothing);
    });
  });
}
