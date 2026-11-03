import 'package:flutter/material.dart';

import 'app_colors.dart';

/// User roles supported in AquaTrace with strict role-based access control.
enum UserRole {
  citizen,
  technician,
  admin;

  String get id => name;

  String get displayName {
    switch (this) {
      case UserRole.citizen:
        return 'Citizen';
      case UserRole.technician:
        return 'Technician';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String get fullTitle {
    switch (this) {
      case UserRole.citizen:
        return 'COMMUNITY CITIZEN';
      case UserRole.technician:
        return 'FIELD TECHNICIAN';
      case UserRole.admin:
        return 'WATER BOARD ADMIN';
    }
  }

  String get avatarLetter {
    switch (this) {
      case UserRole.citizen:
        return 'C';
      case UserRole.technician:
        return 'T';
      case UserRole.admin:
        return 'A';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.citizen:
        return AppColors.roleCitizen;
      case UserRole.technician:
        return AppColors.roleTechnician;
      case UserRole.admin:
        return AppColors.roleAdmin;
    }
  }

  String get defaultRoute {
    switch (this) {
      case UserRole.citizen:
        return '/citizen';
      case UserRole.technician:
        return '/technician';
      case UserRole.admin:
        return '/admin';
    }
  }

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.citizen;
    final normalized = value.trim().toLowerCase();
    for (final role in UserRole.values) {
      if (role.name == normalized ||
          role.displayName.toLowerCase() == normalized) {
        return role;
      }
    }
    return UserRole.citizen;
  }
}
