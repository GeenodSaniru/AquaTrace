import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_roles.dart';
import '../../../core/models/user_model.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import 'profile_settings_screens.dart';

class SharedProfileView extends StatelessWidget {
  const SharedProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final preferences = context.watch<PreferencesService>();
    final user = auth.currentUser;
    final role = user?.role ?? UserRole.citizen;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: theme.isDarkMode
                ? 'Use light appearance'
                : 'Use dark appearance',
            onPressed: theme.toggleTheme,
            icon: Icon(
              theme.isDarkMode
                  ? Icons.wb_sunny_outlined
                  : Icons.nightlight_round_outlined,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Center(
            child: Column(
              children: [
                _ProfileAvatar(user: user, role: role, isDark: isDark),
                const SizedBox(height: 12),
                Text(
                  user?.displayName.isNotEmpty == true
                      ? user!.displayName
                      : 'AquaTrace User',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
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
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (user?.assignedArea.isNotEmpty == true)
                  Text(
                    user!.assignedArea,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Account Information'),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _AccountRow(label: 'Full Name', value: user?.displayName),
                const Divider(height: 18),
                _AccountRow(label: 'Email', value: user?.email),
                const Divider(height: 18),
                _AccountRow(label: 'Phone', value: user?.phoneNumber),
                const Divider(height: 18),
                _AccountRow(label: 'Area', value: user?.assignedArea),
                if (user?.employeeId?.isNotEmpty == true) ...[
                  const Divider(height: 18),
                  _AccountRow(label: 'Employee ID', value: user!.employeeId),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _open(context, const EditProfileScreen()),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Profile'),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Preferences'),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: Text(
                      theme.isDarkMode
                          ? 'Dark appearance is active'
                          : 'Light appearance is active',
                    ),
                    value: theme.isDarkMode,
                    onChanged: (value) => theme.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Accessibility'),
                    subtitle: Text(
                      '${preferences.textSize} text · ${preferences.highContrastMode ? 'high contrast' : 'standard contrast'}',
                    ),
                    leading: const Icon(Icons.accessibility_new_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        _open(context, const AccessibilitySettingsScreen()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Settings & Support'),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notification Settings',
                    onTap: () =>
                        _open(context, const NotificationSettingsScreen()),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.location_on_outlined,
                    title: 'Location Settings',
                    onTap: () => _open(context, const LocationSettingsScreen()),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.security_rounded,
                    title: 'Privacy',
                    onTap: () => _open(context, const PrivacySettingsScreen()),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Accessibility',
                    onTap: () =>
                        _open(context, const AccessibilitySettingsScreen()),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    onTap: () => _open(context, const HelpSupportScreen()),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About AquaTrace',
                    onTap: () => _open(context, const AboutAquaTraceScreen()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Sign Out',
            icon: Icons.logout_rounded,
            isOutlined: true,
            textColor: AppColors.statusDisputed,
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
              }
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'AquaTrace v${AppConfig.appVersion} · ${AppConfig.appOrganization}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _ProfileAvatar extends StatelessWidget {
  final UserModel? user;
  final UserRole role;
  final bool isDark;

  const _ProfileAvatar({
    required this.user,
    required this.role,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? '';
    final photoUrl = user?.photoUrl;
    return Stack(
      children: [
        CircleAvatar(
          radius: 46,
          backgroundColor: role.color.withValues(alpha: 0.18),
          foregroundImage: photoUrl?.isNotEmpty == true
              ? NetworkImage(photoUrl!)
              : null,
          onForegroundImageError: photoUrl?.isNotEmpty == true
              ? (_, _) {}
              : null,
          child: Text(
            name.trim().isNotEmpty
                ? name.trim()[0].toUpperCase()
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
                color: isDark ? AppColors.darkBackground : Colors.white,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.titleMedium);
}

class _AccountRow extends StatelessWidget {
  final String label;
  final String? value;

  const _AccountRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final displayValue = value?.trim().isNotEmpty == true ? value!.trim() : '—';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            displayValue,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}
