import '../../../core/models/mock_data.dart';
import '../../../core/models/notification_item.dart';

/// DEMO DATA ONLY.
///
/// Role-specific notification fixtures used when Firebase is not configured
/// (the app's demo-role sign-in). A configured Firebase session never reads
/// these - real notifications are written by the backend. Each user only ever
/// sees records addressed to their own uid, mirroring production behaviour.
class DemoNotifications {
  DemoNotifications._();

  /// Fixtures keyed by recipient uid. Times are relative to "now".
  static Map<String, List<NotificationItem>> build() {
    final base = DateTime.now();
    DateTime ago(Duration duration) => base.subtract(duration);

    // Citizen: the exact four records shown in the UI design.
    final citizen = MockData.initialNotifications;

    final technician = <NotificationItem>[
      NotificationItem(
        id: 'demo-tech-001',
        recipientUid: MockData.technicianUser.uid,
        title: 'New Job Assigned',
        body:
            'Report AT-2026-00128 at Duplication Road, Colombo 03 has been '
            'assigned to you.',
        reportId: 'AT-2026-00128',
        type: NotificationType.assignment.value,
        createdAt: ago(const Duration(hours: 2)),
      ),
      NotificationItem(
        id: 'demo-tech-002',
        recipientUid: MockData.technicianUser.uid,
        title: 'Repair Status Updated',
        body: 'AT-2026-00126 is completed and awaiting community verification.',
        reportId: 'AT-2026-00126',
        type: NotificationType.update.value,
        createdAt: ago(const Duration(hours: 5)),
      ),
      NotificationItem(
        id: 'demo-tech-003',
        recipientUid: MockData.technicianUser.uid,
        title: 'Report Approved',
        body: 'AT-2026-00124 was verified by admin and assigned to you.',
        reportId: 'AT-2026-00124',
        type: NotificationType.approval.value,
        isRead: true,
        createdAt: ago(const Duration(days: 1)),
      ),
    ];

    final admin = <NotificationItem>[
      NotificationItem(
        id: 'demo-admin-001',
        recipientUid: MockData.adminUser.uid,
        title: 'New Report Submitted',
        body:
            'AT-2026-00125 Burst Pipe at Main Street, Maharagama needs review.',
        reportId: 'AT-2026-00125',
        type: NotificationType.update.value,
        createdAt: ago(const Duration(hours: 1)),
      ),
      NotificationItem(
        id: 'demo-admin-002',
        recipientUid: MockData.adminUser.uid,
        title: 'Dispute Opened',
        body: 'A dispute has been raised on AT-2026-00127. Admin is reviewing.',
        reportId: 'AT-2026-00127',
        type: NotificationType.dispute.value,
        createdAt: ago(const Duration(hours: 5)),
      ),
      NotificationItem(
        id: 'demo-admin-003',
        recipientUid: MockData.adminUser.uid,
        title: 'Technician Assigned',
        body:
            'Kasun Jayawardena was assigned to AT-2026-00128 and has '
            'accepted the job.',
        reportId: 'AT-2026-00128',
        type: NotificationType.assignment.value,
        isRead: true,
        createdAt: ago(const Duration(days: 1)),
      ),
    ];

    return {
      MockData.citizenUser.uid: citizen,
      MockData.technicianUser.uid: technician,
      MockData.adminUser.uid: admin,
    };
  }
}
