import 'package:flutter/material.dart';

/// Centralized color palette for AquaTrace matching the Figma UI specifications.
class AppColors {
  AppColors._();

  // Primary brand navy & cyan
  static const Color primaryNavy = Color(0xFF163A70);
  static const Color primaryNavyDark = Color(0xFF0D2342);
  static const Color primaryNavyDeep = Color(0xFF0A192F);
  static const Color primaryCyan = Color(0xFF00A3E0);
  static const Color primaryCyanLight = Color(0xFF38BDF8);
  static const Color primaryCyanAccent = Color(0xFF06B6D4);

  // Backgrounds & Surfaces (Light)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Backgrounds & Surfaces (Dark)
  static const Color darkBackground = Color(0xFF0B1528);
  static const Color darkSurface = Color(0xFF132742);
  static const Color darkSurfaceSecondary = Color(0xFF1A3356);
  static const Color darkBorder = Color(0xFF1E3A63);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Status Colors (Matching status badges and map pins)
  static const Color statusPending = Color(0xFFF59E0B); // Amber / Orange
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusPendingDarkBg = Color(0xFF452B05);

  static const Color statusAssigned = Color(0xFF0EA5E9); // Sky blue
  static const Color statusAssignedBg = Color(0xFFE0F2FE);
  static const Color statusAssignedDarkBg = Color(0xFF083344);

  static const Color statusOngoing = Color(0xFF2563EB); // Royal Blue
  static const Color statusOngoingBg = Color(0xFFDBEAFE);
  static const Color statusOngoingDarkBg = Color(0xFF1E3A8A);

  static const Color statusCompleted = Color(0xFF10B981); // Emerald Green
  static const Color statusCompletedBg = Color(0xFFD1FAE5);
  static const Color statusCompletedDarkBg = Color(0xFF064E3B);

  static const Color statusDisputed = Color(0xFFEF4444); // Crimson / Red
  static const Color statusDisputedBg = Color(0xFFFEE2E2);
  static const Color statusDisputedDarkBg = Color(0xFF7F1D1D);

  // Priority Colors
  static const Color priorityLow = Color(0xFF0EA5E9);
  static const Color priorityMedium = Color(0xFF10B981);
  static const Color priorityHigh = Color(0xFFF97316);
  static const Color priorityCritical = Color(0xFFEF4444);

  // Role Accent Colors
  static const Color roleCitizen = Color(0xFF10B981);
  static const Color roleTechnician = Color(0xFF3B82F6);
  static const Color roleAdmin = Color(0xFF8B5CF6);
}
