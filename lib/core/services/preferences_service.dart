import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized local persistent preferences store for AquaTrace user settings.
class PreferencesService extends ChangeNotifier {
  static const String _keyPushNotifications = 'pref_push_notifications';
  static const String _keyNearbyFaults = 'pref_nearby_faults';
  static const String _keyRepairVerification = 'pref_repair_verification';
  static const String _keyEmailSummary = 'pref_email_summary';
  static const String _keyLocationServices = 'pref_location_services';
  static const String _keyPrimaryArea = 'pref_primary_area';
  static const String _keyTextSize = 'pref_text_size';
  static const String _keyHighContrast = 'pref_high_contrast';
  static const String _keyAnonymousReports = 'pref_anonymous_reports';
  static const String _keyCommunityVerification = 'pref_community_verification';
  static const String _keyUsageAnalytics = 'pref_usage_analytics';
  static const String _keyLastAuthUid = 'pref_last_auth_uid';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  String _userKey(String key) {
    final uid = lastAuthUid;
    return uid == null ? key : '${key}_$uid';
  }

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  bool get pushNotificationsEnabled =>
      _prefs.getBool(_userKey(_keyPushNotifications)) ?? true;
  Future<void> setPushNotificationsEnabled(bool value) =>
      _setBool(_keyPushNotifications, value);

  bool get nearbyFaultsEnabled =>
      _prefs.getBool(_userKey(_keyNearbyFaults)) ?? true;
  Future<void> setNearbyFaultsEnabled(bool value) =>
      _setBool(_keyNearbyFaults, value);

  bool get repairVerificationEnabled =>
      _prefs.getBool(_userKey(_keyRepairVerification)) ?? true;
  Future<void> setRepairVerificationEnabled(bool value) =>
      _setBool(_keyRepairVerification, value);

  bool get emailSummaryEnabled =>
      _prefs.getBool(_userKey(_keyEmailSummary)) ?? false;
  Future<void> setEmailSummaryEnabled(bool value) =>
      _setBool(_keyEmailSummary, value);

  bool get locationServicesEnabled =>
      _prefs.getBool(_userKey(_keyLocationServices)) ?? true;
  Future<void> setLocationServicesEnabled(bool value) =>
      _setBool(_keyLocationServices, value);

  String get primaryArea =>
      _prefs.getString(_userKey(_keyPrimaryArea)) ?? 'Colombo 03';
  Future<void> setPrimaryArea(String value) async {
    await _prefs.setString(_userKey(_keyPrimaryArea), value);
    notifyListeners();
  }

  String get textSize => _prefs.getString(_userKey(_keyTextSize)) ?? 'Standard';
  double get textScaleFactor => switch (textSize) {
    'Large' => 1.15,
    'Extra Large' => 1.3,
    _ => 1,
  };
  Future<void> setTextSize(String value) async {
    if (!const ['Standard', 'Large', 'Extra Large'].contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported text size');
    }
    await _prefs.setString(_userKey(_keyTextSize), value);
    notifyListeners();
  }

  bool get highContrastMode =>
      _prefs.getBool(_userKey(_keyHighContrast)) ?? false;
  Future<void> setHighContrastMode(bool value) =>
      _setBool(_keyHighContrast, value);

  bool get anonymousReports =>
      _prefs.getBool(_userKey(_keyAnonymousReports)) ?? false;
  Future<void> setAnonymousReports(bool value) =>
      _setBool(_keyAnonymousReports, value);

  bool get communityVerification =>
      _prefs.getBool(_userKey(_keyCommunityVerification)) ?? true;
  Future<void> setCommunityVerification(bool value) =>
      _setBool(_keyCommunityVerification, value);

  bool get usageAnalytics =>
      _prefs.getBool(_userKey(_keyUsageAnalytics)) ?? false;
  Future<void> setUsageAnalytics(bool value) =>
      _setBool(_keyUsageAnalytics, value);

  String? get lastAuthUid => _prefs.getString(_keyLastAuthUid);
  Future<void> setLastAuthUid(String? value) async {
    if (value == null) {
      await _prefs.remove(_keyLastAuthUid);
    } else {
      await _prefs.setString(_keyLastAuthUid, value);
    }
    notifyListeners();
  }

  Future<void> _setBool(String key, bool value) async {
    await _prefs.setBool(_userKey(key), value);
    notifyListeners();
  }
}
