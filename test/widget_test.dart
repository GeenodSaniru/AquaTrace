import 'dart:typed_data';

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
import 'package:aquatrace/features/profile/presentation/profile_settings_screens.dart';
import 'package:aquatrace/features/profile/presentation/shared_profile_view.dart';
import 'package:aquatrace/features/profile/profile_photo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AquaTrace Foundation & Model Tests', () {
    test('Preferences persist per signed-in user', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = PreferencesService(prefs);

      await service.setLastAuthUid('citizen-a');
      await service.setPushNotificationsEnabled(false);
      await service.setNearbyFaultsEnabled(false);
      await service.setLocationServicesEnabled(false);
      await service.setPrimaryArea('Maharagama');
      await service.setTextSize('Extra Large');
      await service.setHighContrastMode(true);
      await service.setAnonymousReports(true);

      await service.setLastAuthUid('citizen-b');
      expect(service.pushNotificationsEnabled, isTrue);
      expect(service.locationServicesEnabled, isTrue);
      expect(service.primaryArea, 'Colombo 03');
      expect(service.textSize, 'Standard');
      expect(service.highContrastMode, isFalse);
      expect(service.anonymousReports, isFalse);

      await service.setLastAuthUid('citizen-a');
      expect(service.pushNotificationsEnabled, isFalse);
      expect(service.nearbyFaultsEnabled, isFalse);
      expect(service.locationServicesEnabled, isFalse);
      expect(service.primaryArea, 'Maharagama');
      expect(service.textScaleFactor, 1.3);
      expect(service.highContrastMode, isTrue);
      expect(service.anonymousReports, isTrue);
    });

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
            ChangeNotifierProvider<PreferencesService>.value(
              value: prefsService,
            ),
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
            ChangeNotifierProvider<PreferencesService>.value(
              value: prefsService,
            ),
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
            ChangeNotifierProvider<PreferencesService>.value(
              value: prefsService,
            ),
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

  group('Profile and settings', () {
    testWidgets('Profile navigation opens each reference settings screen', (
      WidgetTester tester,
    ) async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final preferences = PreferencesService(sharedPreferences);
      final authService = AuthService(preferences);
      final authProvider = AuthProvider(authService);
      await tester.runAsync(
        () => authProvider.signInWithDemoRole(UserRole.technician),
      );
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PreferencesService>.value(
              value: preferences,
            ),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const MaterialApp(home: SharedProfileView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FIELD TECHNICIAN'), findsOneWidget);
      expect(find.text('Employee ID'), findsOneWidget);

      final menuItems = [
        'Edit Profile',
        'Notification Settings',
        'Location Settings',
        'Privacy',
        'Accessibility',
        'Help & Support',
        'About AquaTrace',
      ];
      for (final item in menuItems) {
        final tile = find.widgetWithText(ListTile, item);
        final button = find.widgetWithText(OutlinedButton, item);
        final target = tile.evaluate().isNotEmpty ? tile : button;
        await tester.ensureVisible(target.last);
        await tester.tap(target.last);
        await tester.pumpAndSettle();
        expect(find.text(item), findsWidgets);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Notification choices save and persist for the current user', (
      WidgetTester tester,
    ) async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final preferences = PreferencesService(sharedPreferences);
      await preferences.setLastAuthUid('profile-notifications-user');

      await tester.pumpWidget(
        ChangeNotifierProvider<PreferencesService>.value(
          value: preferences,
          child: const MaterialApp(home: NotificationSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final nearbySwitch = find.widgetWithText(SwitchListTile, 'Nearby Faults');
      await tester.ensureVisible(nearbySwitch);
      await tester.tap(nearbySwitch);
      await tester.pumpAndSettle();
      final saveButton = find.text('Save Notifications');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final restoredPreferences = PreferencesService(sharedPreferences);
      expect(restoredPreferences.nearbyFaultsEnabled, isFalse);
    });

    testWidgets('Location settings persist area and location preference', (
      WidgetTester tester,
    ) async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final preferences = PreferencesService(sharedPreferences);

      await tester.pumpWidget(
        ChangeNotifierProvider<PreferencesService>.value(
          value: preferences,
          child: const MaterialApp(home: LocationSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maharagama').last);
      await tester.pumpAndSettle();
      final locationSwitch = find.widgetWithText(
        SwitchListTile,
        'Location Services',
      );
      await tester.tap(locationSwitch);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Location'));
      await tester.tap(find.text('Save Location'));
      await tester.pumpAndSettle();

      expect(preferences.primaryArea, 'Maharagama');
      expect(preferences.locationServicesEnabled, isFalse);
    });

    testWidgets('Privacy and accessibility choices are persisted and applied', (
      WidgetTester tester,
    ) async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final preferences = PreferencesService(sharedPreferences);

      await tester.pumpWidget(
        ChangeNotifierProvider<PreferencesService>.value(
          value: preferences,
          child: const MaterialApp(home: AccessibilitySettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'High Contrast Mode'),
      );
      await tester.pumpAndSettle();

      expect(preferences.textScaleFactor, 1.15);
      expect(preferences.highContrastMode, isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider<PreferencesService>.value(
          value: preferences,
          child: const MaterialApp(home: PrivacySettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Anonymous Reports'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Privacy Preferences'));
      await tester.tap(find.text('Save Privacy Preferences'));
      await tester.pumpAndSettle();

      expect(preferences.anonymousReports, isTrue);
    });

    testWidgets('Edit profile saves safe fields', (WidgetTester tester) async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final preferences = PreferencesService(sharedPreferences);
      final authService = AuthService(preferences);
      final authProvider = AuthProvider(authService);
      await tester.runAsync(
        () => authProvider.signInWithDemoRole(UserRole.technician),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            Provider<AuthService>.value(value: authService),
          ],
          child: const MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Updated Technician',
      );
      await tester.ensureVisible(find.text('Save Profile'));
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(authProvider.currentUser?.displayName, 'Updated Technician');
      expect(authProvider.currentUser?.role, UserRole.technician);
      expect(authProvider.currentUser?.employeeId, 'WB-2024-087');
    });

    testWidgets('Edit profile cancel discards unsaved changes', (
      WidgetTester tester,
    ) async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final preferences = PreferencesService(sharedPreferences);
      final authService = AuthService(preferences);
      final authProvider = AuthProvider(authService);
      await tester.runAsync(
        () => authProvider.signInWithDemoRole(UserRole.technician),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            Provider<AuthService>.value(value: authService),
          ],
          child: const MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Discarded Name',
      );
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(authProvider.currentUser?.displayName, 'Kasun Jayawardena');
    });

    testWidgets('Profile photo upload errors are shown without losing edits', (
      WidgetTester tester,
    ) async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final preferences = PreferencesService(sharedPreferences);
      final authService = AuthService(preferences);
      final authProvider = AuthProvider(authService);
      await tester.runAsync(
        () => authProvider.signInWithDemoRole(UserRole.citizen),
      );
      final image = XFile.fromData(
        Uint8List.fromList(List<int>.filled(16, 1)),
        name: 'avatar.png',
        mimeType: 'image/png',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            Provider<AuthService>.value(value: authService),
          ],
          child: MaterialApp(
            home: EditProfileScreen(
              photoService: _FailingProfilePhotoService(),
              imagePicker: _FixedImagePicker(image),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change Profile Picture'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Updated Citizen',
      );
      await tester.ensureVisible(find.text('Save Profile'));
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Profile photo upload was denied. Storage access is not enabled for this account.',
        ),
        findsOneWidget,
      );
      expect(authProvider.currentUser?.displayName, 'Amal Perera');
    });
  });
}

class _FixedImagePicker extends ImagePicker {
  final XFile image;

  _FixedImagePicker(this.image);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => image;
}

class _FailingProfilePhotoService extends ProfilePhotoService {
  @override
  Future<String> upload({required String uid, required XFile image}) async {
    throw StateError('permission-denied');
  }
}
