import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../services/push_messaging_service.dart';

/// Offers to turn on push notifications and explains permission problems.
///
/// * not asked yet  -> "Enable" button (user-initiated prompt)
/// * denied         -> explains that only system settings can change it
/// * registration failed -> retry
/// * granted / unsupported / unknown -> nothing is shown
class PushPermissionBanner extends StatefulWidget {
  const PushPermissionBanner({super.key});

  @override
  State<PushPermissionBanner> createState() => _PushPermissionBannerState();
}

class _PushPermissionBannerState extends State<PushPermissionBanner>
    with WidgetsBindingObserver {
  bool _dismissed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have changed the permission in system settings.
    if (state == AppLifecycleState.resumed) {
      _service(listen: false)?.refreshStatus();
    }
  }

  PushMessagingService? _service({required bool listen}) {
    try {
      return listen
          ? context.watch<PushMessagingService>()
          : context.read<PushMessagingService>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _enable(PushMessagingService service) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await service.requestPermission();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == PushPermissionStatus.denied) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Push notifications stay off. You can allow them in system '
            'settings.',
          ),
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    var opened = false;
    try {
      opened = await Geolocator.openAppSettings();
    } on Object {
      opened = false;
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Open your device settings to change notifications.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = _service(listen: true);
    if (service == null || _dismissed || !service.isUserEnabled) {
      return const SizedBox.shrink();
    }

    final String title;
    final String message;
    final String actionLabel;
    final VoidCallback? onAction;
    switch (service.status) {
      case PushPermissionStatus.notDetermined:
        title = 'Turn on push notifications';
        message =
            'Get report updates and alerts even when AquaTrace is closed.';
        actionLabel = 'Enable';
        onAction = _busy ? null : () => _enable(service);
      case PushPermissionStatus.denied:
        title = 'Push notifications are blocked';
        message =
            'Allow notifications for AquaTrace in your device settings to '
            'receive alerts when the app is closed.';
        actionLabel = 'Open settings';
        onAction = _openSettings;
      case PushPermissionStatus.granted when service.lastError != null:
        title = 'Push notifications need attention';
        message = service.lastError!;
        actionLabel = 'Try again';
        onAction = _busy
            ? null
            : () async {
                setState(() => _busy = true);
                await service.refreshStatus();
                if (mounted) setState(() => _busy = false);
              };
      default:
        return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.primaryCyan.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.notifications_active_outlined,
              size: 22,
              color: AppColors.primaryCyan,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(48, 40),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}
