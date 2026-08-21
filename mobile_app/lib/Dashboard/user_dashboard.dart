// mobile_app/lib/Dashboard/user_dashboard.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../AdminGroupPage.dart';
import 'dashboard_model.dart';
import 'dashboard_card.dart';
import '../Calendar/calendar_page.dart';

class UserDashboardView extends StatelessWidget {
  final UserDashboardData data;
  final VoidCallback onRefresh;

  const UserDashboardView({
    Key? key,
    required this.data,
    required this.onRefresh,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'แดชบอร์ดส่วนตัว',
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
                      margin: const EdgeInsets.only(right: 8),
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
                    FutureBuilder<SharedPreferences>(
                      future: SharedPreferences.getInstance(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final prefs = snapshot.data!;
                        final role = prefs.getString('role');

                        if (role == 'ADMIN') {
                          return OutlinedButton.icon(
                            onPressed: () async {
                              await prefs.setString('current_mode', 'ADMIN_MODE');
                              try {
                                const storage = FlutterSecureStorage();
                                await storage.write(key: 'current_mode', value: 'ADMIN_MODE');
                              } catch (e) {
                                debugPrint("⚠️ SecureStorage Write Error: $e");
                              }

                              if (!context.mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminGroupPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.orange),
                            label: const Text(
                              'โหมดแอดมิน',
                              style: TextStyle(fontSize: 12, color: Colors.orange, fontFamily: 'Kanit', fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.orange.shade50,
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: DashboardCardWidget(
                    title: 'การจองของฉัน',
                    value: '${data.myTotalBookings}',
                    icon: Icons.bookmark_rounded,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DashboardCardWidget(
                    title: 'รออนุมัติ',
                    value: '${data.pendingApprovals}',
                    icon: Icons.pending_actions_rounded,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Recent Room Bookings Section
            const Text(
              'รายการจองห้องล่าสุด',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003E75), fontFamily: 'Kanit'),
            ),
            const SizedBox(height: 12),
            if (data.recentRooms.isEmpty)
              _buildEmptyState('ไม่มีประวัติการจองห้อง')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.recentRooms.length,
                itemBuilder: (context, index) {
                  final item = data.recentRooms[index];
                  return _buildModernListItem(
                    icon: Icons.meeting_room_rounded,
                    iconColor: Colors.blue,
                    title: item['room']?['name'] ?? 'ห้องประชุม',
                    status: item['status'] ?? 'UNKNOWN',
                  );
                },
              ),
            const SizedBox(height: 24),

            // Recent Vehicle Bookings Section
            const Text(
              'รายการจองพาหนะล่าสุด',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003E75), fontFamily: 'Kanit'),
            ),
            const SizedBox(height: 12),
            if (data.recentVehicles.isEmpty)
              _buildEmptyState('ไม่มีประวัติการจองยานพาหนะ')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.recentVehicles.length,
                itemBuilder: (context, index) {
                  final item = data.recentVehicles[index];
                  return _buildModernListItem(
                    icon: Icons.directions_car_rounded,
                    iconColor: Colors.indigo,
                    title: item['vehicle']?['model'] ?? 'ยานพาหนะ',
                    status: item['status'] ?? 'UNKNOWN',
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 🟢 Widget เสริมสำหรับตกแต่ง List ให้สวยงาม
  Widget _buildModernListItem({required IconData icon, required Color iconColor, required String title, required String status}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kanit', fontSize: 16),
        ),
        subtitle: Text(
          'สถานะ: $status',
          style: TextStyle(color: Colors.grey.shade600, fontFamily: 'Kanit', fontSize: 13),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Kanit'),
          ),
        ],
      ),
    );
  }
}