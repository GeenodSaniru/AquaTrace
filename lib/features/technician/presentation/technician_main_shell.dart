import 'package:flutter/material.dart';

import '../../../core/models/report_model.dart';
import '../../map/presentation/shared_map_view.dart';
import '../../notifications/presentation/shared_notifications_view.dart';
import '../../profile/presentation/shared_profile_view.dart';
import '../../reports/presentation/shared_reports_view.dart';
import 'technician_home_view.dart';

/// 5-tab main container shell for Technician role.
class TechnicianMainShell extends StatefulWidget {
  final int initialTab;

  const TechnicianMainShell({super.key, this.initialTab = 0});

  @override
  State<TechnicianMainShell> createState() => _TechnicianMainShellState();
}

class _TechnicianMainShellState extends State<TechnicianMainShell> {
  late int _currentIndex;
  ReportModel? _selectedMapReport;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  void _onTabSelected(int index, [ReportModel? report]) {
    setState(() {
      _currentIndex = index;
      _selectedMapReport = report;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      TechnicianHomeView(onNavigateTab: _onTabSelected),
      const SharedReportsView(),
      SharedMapView(initialReport: _selectedMapReport),
      const SharedNotificationsView(),
      const SharedProfileView(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build_rounded),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
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
