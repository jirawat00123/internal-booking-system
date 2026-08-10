// mobile_app/lib/Dashboard/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'dashboard_model.dart';
import 'dashboard_card.dart';
import 'dashboard_chart.dart';

class AdminDashboardView extends StatelessWidget {
  final AdminDashboardData data;
  final VoidCallback onRefresh;
  final Function(String type, String format) onExport;

  const AdminDashboardView({
    Key? key,
    required this.data,
    required this.onRefresh,
    required this.onExport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section & Export Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ภาพรวมระบบ (Admin)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (data.permissions.canExportReport)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.download, color: Colors.blue),
                    tooltip: 'ส่งออกรายงาน',
                    onSelected: (value) {
                      final parts = value.split('_');
                      onExport(parts[0], parts[1]);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'room_json',
                        child: Text('ส่งออกรายงานห้องพัก (JSON)'),
                      ),
                      const PopupMenuItem(
                        value: 'vehicle_json',
                        child: Text('ส่งออกรายงานยานพาหนะ (JSON)'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Metrics Cards Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                DashboardCardWidget(
                  title: 'ห้องทั้งหมด',
                  value: '${data.totalRooms}',
                  icon: Icons.meeting_room,
                  color: Colors.blue,
                ),
                DashboardCardWidget(
                  title: 'ยานพาหนะทั้งหมด',
                  value: '${data.totalVehicles}',
                  icon: Icons.directions_car,
                  color: Colors.indigo,
                ),
                DashboardCardWidget(
                  title: 'รายการจองวันนี้',
                  value: '${data.todayTotalBookings}',
                  icon: Icons.today,
                  color: Colors.orange,
                ),
                DashboardCardWidget(
                  title: 'ผู้ใช้งาน Active',
                  value: '${data.activeUsers}',
                  icon: Icons.people,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pie Charts Section
            DashboardPieChartWidget(
              title: 'สถานะการจองห้องประชุม',
              dataMap: data.roomStats,
            ),
            const SizedBox(height: 16),
            DashboardPieChartWidget(
              title: 'สถานะการจองยานพาหนะ',
              dataMap: data.vehicleStats,
            ),
          ],
        ),
      ),
    );
  }
}
