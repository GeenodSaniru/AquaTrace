import 'package:flutter/foundation.dart';

/// Application configuration and environment constants for AquaTrace.
class AppConfig {
  AppConfig._();

  static const String appName = 'AquaTrace';
  static const String appTagline = 'REPORT • REPAIR • VERIFY';
  static const String appVersion = '1.0.0';
  static const String appOrganization = 'National Water Board · Sri Lanka';

  /// Default map center: Colombo, Sri Lanka
  static const double defaultLatitude = 6.9271;
  static const double defaultLongitude = 79.8612;
  static const double defaultZoom = 13.0;

  /// OpenStreetMap tile server configuration
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmUserAgent =
      'com.aquatrace.app/1.0.0 (contact: info@waterboard.lk)';

  /// Verification settings
  static const double defaultVerificationRadiusMeters = 500.0;
  static const int defaultVerificationThreshold = 3;

  /// In debug/test environments, fallback to mock/demo data if Firebase
  /// options or credentials have not been configured by the developer yet.
  static bool enableDemoAuthFallback = true;
  static bool isDebugMode = kDebugMode;
}
