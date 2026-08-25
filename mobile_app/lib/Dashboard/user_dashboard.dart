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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.calendar_month,
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
                    FutureBuilder<SharedPreferences>(
                      future: SharedPreferences.getInstance(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final prefs = snapshot.data!;
                        final role = prefs.getString('role');

                        // 🌟 แสดงปุ่มนี้เฉพาะบัญชีที่มีสิทธิ์เป็น ADMIN เท่านั้น
                        if (role == 'ADMIN') {
                          return OutlinedButton.icon(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              // อัปเดตสถานะกลับเป็น ADMIN_MODE
                              await prefs.setString(
                                'current_mode',
                                'ADMIN_MODE',
                              );
                              try {
                                const storage = FlutterSecureStorage();
                                await storage.write(
                                  key: 'current_mode',
                                  value: 'ADMIN_MODE',
                                );
                              } catch (e) {
                                debugPrint(
                                  "⚠️ SecureStorage Write Error (Mode): $e",
                                );
                              }

                              navigator.pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const AdminGroupPage(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.swap_horiz,
                              size: 16,
                              color: Colors.orange,
                            ),
                            label: const Text(
                              'กลับสู่โหมดแอดมิน',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontFamily: 'Kanit',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
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
            const SizedBox(height: 16),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: DashboardCardWidget(
                    title: 'การจองทั้งหมดของฉัน',
                    value: '${data.myTotalBookings}',
                    icon: Icons.bookmark,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DashboardCardWidget(
                    title: 'รอการอนุมัติ',
                    value: '${data.pendingApprovals}',
                    icon: Icons.pending_actions,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Room Bookings Section
            const Text(
              'รายการจองห้องล่าสุด',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (data.recentRooms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'ไม่มีประวัติการจองห้อง',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.recentRooms.length,
                itemBuilder: (context, index) {
                  final item = data.recentRooms[index];
                  final roomName = item['room']?['name'] ?? 'ห้องประชุม';
                  final status = item['status'] ?? 'UNKNOWN';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.meeting_room,
                        color: Colors.blue,
                      ),
                      title: Text(roomName),
                      subtitle: Text('สถานะ: $status'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),

            // Recent Vehicle Bookings Section
            const Text(
              'รายการจองยานพาหนะล่าสุด',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (data.recentVehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'ไม่มีประวัติการจองยานพาหนะ',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.recentVehicles.length,
                itemBuilder: (context, index) {
                  final item = data.recentVehicles[index];
                  final vehicleName = item['vehicle']?['model'] ?? 'ยานพาหนะ';
                  final status = item['status'] ?? 'UNKNOWN';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.directions_car,
                        color: Colors.indigo,
                      ),
                      title: Text(vehicleName),
                      subtitle: Text('สถานะ: $status'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
