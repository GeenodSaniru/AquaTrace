import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_roles.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../profile_photo_service.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfilePhotoService? photoService;
  final ImagePicker? imagePicker;

  const EditProfileScreen({super.key, this.photoService, this.imagePicker});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late final ImagePicker _picker;
  late final ProfilePhotoService _photoService;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _photoService = widget.photoService ?? ProfilePhotoService();
    _picker = widget.imagePicker ?? ImagePicker();
    final user = context.read<AuthProvider>().currentUser;
    _nameController.text = user?.displayName ?? '';
    _phoneController.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectPhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > ProfilePhotoService.maxPhotoBytes) {
        _showMessage('Choose an image smaller than 5 MB.');
        return;
      }
      if (!ProfilePhotoService.supportsContentType(
        (image.mimeType ?? 'image/jpeg').toLowerCase(),
      )) {
        _showMessage('Choose a JPEG, PNG, WebP, or HEIC image.');
        return;
      }

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
      _showMessage(
        'New profile picture selected. Save your profile to apply it.',
      );
    } on PlatformException catch (error) {
      if (mounted) {
        _showMessage(
          error.code == 'photo_access_denied'
              ? 'Allow photo access in your device settings to choose a picture.'
              : 'Unable to open your photo library. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to select that image. Please try again.');
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      _showMessage('Your profile is not available. Please sign in again.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await _photoService.upload(
          uid: user.uid,
          image: _selectedImage!,
        );
      }

      auth.clearError();
      await auth.updateProfile(
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        photoUrl: photoUrl,
      );
      if (auth.errorMessage != null) throw StateError(auth.errorMessage!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('permission-denied') ||
        message.contains('unauthorized')) {
      return 'Profile photo upload was denied. Storage access is not enabled for this account.';
    }
    if (message.contains('unavailable') ||
        message.contains('network') ||
        message.contains('retry-limit-exceeded')) {
      return 'Could not connect. Check your connection and try again.';
    }
    return message.replaceFirst('Bad state: ', '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _avatar(UserModel? user) {
    final role = user?.role ?? UserRole.citizen;
    final initials = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()[0].toUpperCase()
        : role.avatarLetter;
    final fallback = ColoredBox(
      color: role.color.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: role.color,
          ),
        ),
      ),
    );
    final image = _selectedImageBytes != null
        ? Image.memory(
            _selectedImageBytes!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : user?.photoUrl?.isNotEmpty == true
        ? Image.network(
            user!.photoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;

    return SizedBox(width: 92, height: 92, child: ClipOval(child: image));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Update your personal and contact details.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  _avatar(user),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _selectPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Change Profile Picture'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your full name.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: user?.email ?? '',
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                helperText: 'Email address cannot be changed here.',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              validator: (value) {
                final phone = value?.trim() ?? '';
                if (phone.isEmpty) return 'Enter your phone number.';
                if (phone.length < 7) return 'Enter a valid phone number.';
                return null;
              },
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Save Profile',
              icon: Icons.check_rounded,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveProfile,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late bool _reportUpdates;
  late bool _nearbyFaults;
  late bool _repairVerification;
  late bool _emailSummary;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final preferences = context.read<PreferencesService>();
    _reportUpdates = preferences.pushNotificationsEnabled;
    _nearbyFaults = preferences.nearbyFaultsEnabled;
    _repairVerification = preferences.repairVerificationEnabled;
    _emailSummary = preferences.emailSummaryEnabled;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final preferences = context.read<PreferencesService>();
    await preferences.setPushNotificationsEnabled(_reportUpdates);
    await preferences.setNearbyFaultsEnabled(_nearbyFaults);
    await preferences.setRepairVerificationEnabled(_repairVerification);
    await preferences.setEmailSummaryEnabled(_emailSummary);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification preferences saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose which AquaTrace updates you receive.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  _switch(
                    'Report Updates',
                    'Status changes for reports you submitted',
                    _reportUpdates,
                    (value) => setState(() => _reportUpdates = value),
                  ),
                  const Divider(height: 1),
                  _switch(
                    'Nearby Faults',
                    'Important reports in your local area',
                    _nearbyFaults,
                    (value) => setState(() => _nearbyFaults = value),
                  ),
                  const Divider(height: 1),
                  _switch(
                    'Repair Verification',
                    'Requests to verify completed repairs',
                    _repairVerification,
                    (value) => setState(() => _repairVerification = value),
                  ),
                  const Divider(height: 1),
                  _switch(
                    'Email Summary',
                    'A weekly AquaTrace activity summary',
                    _emailSummary,
                    (value) => setState(() => _emailSummary = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choices are saved on this device. Push notifications and weekly email are not connected in this build.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Save Notifications',
            icon: Icons.notifications_outlined,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _switch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: _saving ? null : onChanged,
    );
  }
}

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  static const _areas = [
    'Colombo 03',
    'Colombo North',
    'Maharagama',
    'Nugegoda',
    'Kottawa',
  ];
  late bool _locationEnabled;
  late String _primaryArea;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final preferences = context.read<PreferencesService>();
    _locationEnabled = preferences.locationServicesEnabled;
    _primaryArea = preferences.primaryArea;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final preferences = context.read<PreferencesService>();
    await preferences.setLocationServicesEnabled(_locationEnabled);
    await preferences.setPrimaryArea(_primaryArea);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location preferences saved successfully.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = [..._areas];
    if (!areas.contains(_primaryArea)) areas.add(_primaryArea);

    return Scaffold(
      appBar: AppBar(title: const Text('Location Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Control location access and your service area.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                title: const Text('Location Services'),
                subtitle: const Text('Use GPS for accurate fault reporting'),
                value: _locationEnabled,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _locationEnabled = value),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Primary Area', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _primaryArea,
            decoration: const InputDecoration(hintText: 'Select an option'),
            items: areas
                .map((area) => DropdownMenuItem(value: area, child: Text(area)))
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _primaryArea = value);
                  },
          ),
          const SizedBox(height: 8),
          Text(
            'Used for nearby reports and alerts. This preference is saved on this device; GPS access still depends on device permission and is not connected to this setting yet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Save Location',
            icon: Icons.location_on_outlined,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  late bool _communityVerification;
  late bool _anonymousReports;
  late bool _usageAnalytics;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final preferences = context.read<PreferencesService>();
    _communityVerification = preferences.communityVerification;
    _anonymousReports = preferences.anonymousReports;
    _usageAnalytics = preferences.usageAnalytics;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final preferences = context.read<PreferencesService>();
    await preferences.setCommunityVerification(_communityVerification);
    await preferences.setAnonymousReports(_anonymousReports);
    await preferences.setUsageAnalytics(_usageAnalytics);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy preferences saved on this device.'),
        ),
      );
    }
  }

  Future<void> _downloadData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Data export is unavailable until account data sync is enabled.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Manage data sharing and account security.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  _switch(
                    'Community Verification',
                    'Allow nearby citizens to verify repairs',
                    _communityVerification,
                    (value) => setState(() => _communityVerification = value),
                  ),
                  const Divider(height: 1),
                  _switch(
                    'Anonymous Reports',
                    'Hide your name on public fault reports',
                    _anonymousReports,
                    (value) => setState(() => _anonymousReports = value),
                  ),
                  const Divider(height: 1),
                  _switch(
                    'Usage Analytics',
                    'Help improve AquaTrace with anonymous usage data',
                    _usageAnalytics,
                    (value) => setState(() => _usageAnalytics = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'These choices are stored on this device. Anonymous reporting, verification, analytics, and data-export services are not connected in this build.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _downloadData,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download My Data'),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Save Privacy Preferences',
            icon: Icons.security_outlined,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _switch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: _saving ? null : onChanged,
    );
  }
}

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<PreferencesService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Adjust reading size and visual contrast.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          Text('Text Size', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: preferences.textSize,
            items: const [
              DropdownMenuItem(value: 'Standard', child: Text('Standard')),
              DropdownMenuItem(value: 'Large', child: Text('Large')),
              DropdownMenuItem(
                value: 'Extra Large',
                child: Text('Extra Large'),
              ),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await preferences.setTextSize(value);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Text size updated across AquaTrace.'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Changes text throughout the entire app.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                title: const Text('High Contrast Mode'),
                subtitle: const Text(
                  'Stronger text, border, and control contrast',
                ),
                value: preferences.highContrastMode,
                onChanged: preferences.setHighContrastMode,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Preview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Readable primary text',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text('Supporting information remains clear.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _supportPhone = '+94 11 234 5678';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Get answers or contact the AquaTrace team.'),
          const SizedBox(height: 16),
          const AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  _HelpQuestion(
                    question: 'How do I report a fault?',
                    answer: 'Open Home and select Report a Water Fault. Add a photo, confirm the location, and submit.',
                  ),
                  Divider(height: 1),
                  _HelpQuestion(
                    question: 'How do I verify a repair?',
                    answer: 'Open the completed repair notification or report and follow the verification prompt when it is available.',
                  ),
                  Divider(height: 1),
                  _HelpQuestion(
                    question: 'Who can see my reports?',
                    answer: 'Reports are visible to signed-in AquaTrace users so the community and Water Board team can coordinate repairs.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Contact Support',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.support_agent_outlined),
                const SizedBox(width: 12),
                const Expanded(child: Text('Water Board Support Desk')),
                IconButton(
                  tooltip: 'Copy support phone number',
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: _supportPhone),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Support phone number copied.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: SelectableText(_supportPhone)),
        ],
      ),
    );
  }
}

class _HelpQuestion extends StatelessWidget {
  final String question;
  final String answer;

  const _HelpQuestion({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(question),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [Align(alignment: Alignment.centerLeft, child: Text(answer))],
    );
  }
}

class AboutAquaTraceScreen extends StatelessWidget {
  const AboutAquaTraceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About AquaTrace')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.water_drop_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            AppConfig.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Report · Repair · Verify',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          Text(
            'A community-powered water infrastructure platform for the National Water Board of Sri Lanka.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Version ${AppConfig.appVersion}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppConfig.appOrganization,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
