import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_roles.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';

/// User profile and application settings view conforming to the AquaTrace design system.
class SharedProfileView extends StatelessWidget {
  const SharedProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final prefsService = Provider.of<PreferencesService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authProvider.currentUser;
    final role = user?.role ?? UserRole.citizen;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode
                  ? Icons.wb_sunny_outlined
                  : Icons.nightlight_round_outlined,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header Card
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: role.color.withValues(alpha: 0.18),
                        child: Text(
                          user?.displayName.isNotEmpty == true
                              ? user!.displayName[0].toUpperCase()
                              : role.avatarLetter,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: role.color,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBackground
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'AquaTrace User',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: role.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: role.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      role.fullTitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: role.color,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account Information
            Text(
              'Account Information',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _buildInfoRow('Full Name', user?.displayName ?? '—', isDark),
                  const Divider(height: 18),
                  _buildInfoRow('Email', user?.email ?? '—', isDark),
                  const Divider(height: 18),
                  _buildInfoRow('Phone', user?.phoneNumber ?? '—', isDark),
                  const Divider(height: 18),
                  _buildInfoRow('Area', user?.assignedArea ?? '—', isDark),
                  if (user?.employeeId != null) ...[
                    const Divider(height: 18),
                    _buildInfoRow('Employee ID', user!.employeeId!, isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Preferences Section
            Text(
              'Preferences',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      themeProvider.isDarkMode
                          ? 'Dark appearance is active'
                          : 'Light appearance is active',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: themeProvider.isDarkMode,
                    activeThumbColor: AppColors.primaryCyan,
                    onChanged: (val) {
                      themeProvider.setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Push Notifications',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Report updates and alerts',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: prefsService.pushNotificationsEnabled,
                    activeThumbColor: AppColors.primaryCyan,
                    onChanged: (val) {
                      prefsService.setPushNotificationsEnabled(val);
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Location Services',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'For accurate fault reporting',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: prefsService.locationServicesEnabled,
                    activeThumbColor: AppColors.primaryCyan,
                    onChanged: (val) {
                      prefsService.setLocationServicesEnabled(val);
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings & Support
            Text(
              'Settings & Support',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notification Settings',
                    onTap: () => _showNotice(
                      context,
                      'Notification preferences assigned to Member 2.',
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  _buildSettingsTile(
                    icon: Icons.location_on_outlined,
                    title: 'Location Settings',
                    onTap: () => _showNotice(
                      context,
                      'Location settings assigned to Member 2.',
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  _buildSettingsTile(
                    icon: Icons.security_rounded,
                    title: 'Privacy Controls',
                    onTap: () => _showNotice(
                      context,
                      'Privacy controls assigned to Member 2.',
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  _buildSettingsTile(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Accessibility',
                    onTap: () => _showNotice(
                      context,
                      'Accessibility options assigned to Member 2.',
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  _buildSettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    onTap: () => _showNotice(
                      context,
                      'Water Board Support Desk: +94 11 234 5678',
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  _buildSettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About AquaTrace',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: AppConfig.appName,
                        applicationVersion: AppConfig.appVersion,
                        applicationLegalese: AppConfig.appOrganization,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out Button
            AppButton(
              label: 'Sign Out',
              icon: Icons.logout_rounded,
              isOutlined: true,
              textColor: AppColors.statusDisputed,
              onPressed: () async {
                await authProvider.signOut();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
                }
              },
            ),
            const SizedBox(height: 16),

            // Footer
            Center(
              child: Text(
                'AquaTrace v${AppConfig.appVersion} · ${AppConfig.appOrganization}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.lightTextMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.primaryNavy),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.lightTextMuted,
      ),
      onTap: onTap,
    );
  }

  void _showNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
