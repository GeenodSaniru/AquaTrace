import 'package:flutter/foundation.dart';

import 'app_exception.dart';

/// Centralized utility for converting arbitrary thrown errors into
/// user-friendly, localized error messages.
class ErrorHandler {
  ErrorHandler._();

  static String getUserMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }

    final errStr = error.toString().toLowerCase();

    if (errStr.contains('user-not-found') ||
        errStr.contains('invalid-credential')) {
      return 'Incorrect email address or password. Please verify your credentials.';
    }
    if (errStr.contains('wrong-password')) {
      return 'The password entered is incorrect. Please try again or reset your password.';
    }
    if (errStr.contains('email-already-in-use')) {
      return 'An account with this email address already exists. Please sign in instead.';
    }
    if (errStr.contains('network-request-failed') ||
        errStr.contains('socketexception')) {
      return 'Network connectivity error. Please check your internet connection.';
    }
    if (errStr.contains('permission-denied')) {
      return 'You do not have permission to perform this action.';
    }
    if (errStr.contains('requires-recent-login')) {
      return 'This action requires recent authentication. Please sign in again.';
    }

    if (kDebugMode) {
      return error.toString();
    }
    return 'An unexpected error occurred. Please try again.';
  }

  static void logError(dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[AquaTrace Error] $error');
      if (stackTrace != null) {
        debugPrint('[AquaTrace StackTrace] $stackTrace');
      }
    }
  }
}
