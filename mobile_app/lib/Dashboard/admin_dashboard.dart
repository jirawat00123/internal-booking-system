// mobile_app/lib/Dashboard/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'dashboard_model.dart';
import 'dashboard_card.dart';
import 'dashboard_chart.dart';
import '../Calendar/calendar_page.dart';

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
      color: const Color(0xFF003E75),
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
                  'ภาพรวมระบบ',
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                    fontFamily: 'Kanit',
                  ),
                ),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.deepPurple,
                        ),
                        tooltip: 'ดูปฏิทินการจอง',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CalendarPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    if (data.permissions.canExportReport) ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.download_rounded, color: Colors.blue),
                          tooltip: 'ส่งออกรายงาน',
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) {
                            final parts = value.split('_');
                            onExport(parts[0], parts[1]);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'room_json',
                              child: Text('ส่งออกรายงานห้องพัก (JSON)', style: TextStyle(fontFamily: 'Kanit')),
                            ),
                            const PopupMenuItem(
                              value: 'vehicle_json',
                              child: Text('ส่งออกรายงานยานพาหนะ (JSON)', style: TextStyle(fontFamily: 'Kanit')),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

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
                  icon: Icons.meeting_room_rounded,
                  color: Colors.blue,
                ),
                DashboardCardWidget(
                  title: 'พาหนะทั้งหมด',
                  value: '${data.totalVehicles}',
                  icon: Icons.directions_car_rounded,
                  color: Colors.indigo,
                ),
                DashboardCardWidget(
                  title: 'รายการจองวันนี้',
                  value: '${data.todayTotalBookings}',
                  icon: Icons.today_rounded,
                  color: Colors.orange,
                ),
                DashboardCardWidget(
                  title: 'ผู้ใช้งาน Active',
                  value: '${data.activeUsers}',
                  icon: Icons.people_rounded,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),

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