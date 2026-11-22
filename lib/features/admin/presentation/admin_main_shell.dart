import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/navigation/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/presentation/shared_map_view.dart';
import '../../notifications/presentation/activity_history_screen.dart';
import '../../profile/presentation/shared_profile_view.dart';
import 'admin_dashboard_view.dart';
import 'admin_reports_view.dart';

/// 5-tab main container shell for Admin role.
class AdminMainShell extends StatefulWidget {
  final int initialTab;

  const AdminMainShell({super.key, this.initialTab = 0});

  @override
  State<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends State<AdminMainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// The dashboard calls `onNavigateTab(3)` for its notification bell. Tab 3
  /// is now the report Activity History (per the design), so the bell opens
  /// the notification list instead of switching tabs.
  void _onDashboardNavigate(int index) {
    if (index == 3) {
      unawaited(Navigator.of(context).pushNamed(AppRouter.notifications));
    } else {
      _onTabSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.currentRole != UserRole.admin) {
      return const Scaffold(
        body: Center(child: Text('Administrator access is required.')),
      );
    }
    final List<Widget> tabs = [
      AdminDashboardView(onNavigateTab: _onDashboardNavigate),
      const AdminReportsView(),
      const SharedMapView(),
      const ActivityHubView(),
      const SharedProfileView(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_toggle_off_rounded),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
