import 'package:intl/intl.dart';

import '../../../core/models/firestore_time.dart';

/// Time presentation shared by the notification list and activity timeline.
class NotificationFormatters {
  NotificationFormatters._();

  /// Short relative time: "Just now", "5m ago", "2h ago", "3d ago", then a
  /// calendar date after a week. Unknown times and clock-skewed (future)
  /// times degrade gracefully instead of showing "0m ago" or negative values.
  static String relativeTime(DateTime time, {DateTime? now}) {
    if (!isKnownTime(time)) return 'Time unavailable';
    final difference = (now ?? DateTime.now()).difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('d MMM yyyy').format(time.toLocal());
  }

  /// Full timestamp in the format used by the activity timeline design,
  /// e.g. "24 Sep 2026 – 10:32 AM".
  static String absoluteTime(DateTime time) {
    if (!isKnownTime(time)) return 'Time unavailable';
    return DateFormat('d MMM yyyy – h:mm a').format(time.toLocal());
  }
}
