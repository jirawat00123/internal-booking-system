// mobile_app/lib/Dashboard/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dashboard_model.dart';
import 'dashboard_service.dart';
import '../Calendar/calendar_page.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({Key? key}) : super(key: key);

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with SingleTickerProviderStateMixin {
  final DashboardService _dashboardService = DashboardService();
  late Future<DashboardData> _dashboardDataFuture;
  late TabController _tabController;
  int _selectedDateRangeDays = 0;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();
  }

  void _loadDashboardData() {
    setState(() {
      _dashboardDataFuture = _dashboardService.fetchDashboardStats().then((
        res,
      ) {
        if (res['success'] == true && res['data'] != null) {
          return DashboardData.fromJson(res['data'] as Map<String, dynamic>);
        }
        throw Exception(res['error'] ?? 'ไม่สามารถโหลดข้อมูลได้');
      });
    });
  }

  Future<void> _handleRefresh() async {
    _loadDashboardData();
    await _dashboardDataFuture.catchError((_) => null);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // (ลบฟังก์ชัน _getStatusColor และ _getStatusText ออกทั้งหมด)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'ปฏิทินการจอง',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'เกิดข้อผิดพลาด: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _handleRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('ลองใหม่'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('ไม่พบข้อมูล'));
          }

          // หมายเหตุ: โครงสร้างผูกกับ API ยังคงอยู่ แต่ UI ภายในปรับใหม่ตามดีไซน์ล่าสุด
          return Column(
            children: [
              _buildTimeRangeSelector(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKpiSummaryCards(),
                        const SizedBox(height: 20),
                        _buildTabBar(),
                        const SizedBox(height: 16),
                        _buildResourceOverviewList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ช่วงเวลา: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              _buildDateChip('3 วันที่แล้ว', -3),
              const SizedBox(width: 4),
              _buildDateChip('วันนี้', 0),
              const SizedBox(width: 4),
              _buildDateChip('3 วันข้างหน้า', 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, int days) {
    final isSelected = _selectedDateRangeDays == days;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: Colors.grey.shade200,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedDateRangeDays = days;
            _selectedDate = DateTime.now().add(Duration(days: days));
            // TODO: สร้าง Logic เพื่อ Fetch ข้อมูลตามช่วงเวลาที่เลือก
          });
        }
      },
    );
  }

  Widget _buildKpiSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'ห้องประชุมกำลังใช้งาน',
                value: '1 / 3',
                subtitle: 'ว่าง 2 ห้อง',
                icon: Icons.meeting_room,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'ยานพาหนะกำลังใช้งาน',
                value: '2 / 5',
                subtitle: 'รอปล่อยรถ 1 คัน',
                icon: Icons.directions_car,
                color: Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        labelColor: Colors.black87,
        unselectedLabelColor: Colors.black54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'ทั้งหมด'),
          Tab(text: 'ห้องประชุม'),
          Tab(text: 'ยานพาหนะ'),
        ],
        onTap: (index) => setState(() {}),
      ),
    );
  }

  Widget _buildResourceOverviewList() {
    return Column(
      children: [
        if (_tabController.index == 0 || _tabController.index == 1) ...[
          _buildRoomStatusCard(
            roomName: 'ห้องประชุมสายน้ำ',
            capacity: 9,
            isInUse: true,
            currentBookingUser: 'นายรณกฤต เหลืองอ่อน (ซัน)',
            timeRange: '03:00 - 05:00 น.',
          ),
          const SizedBox(height: 10),
        ],
        if (_tabController.index == 0 || _tabController.index == 2) ...[
          _buildVehicleStatusCard(
            vehicleName: 'TOYOTA HILUX REVO (3กด 9459)',
            status: VehicleStatus.awaitingRelease,
            currentUser: 'นายวรวัฒน์ สุวรรณแก้ว (ชื่น)',
            timeRange: '08:07 - 17:00 น.',
          ),
          const SizedBox(height: 10),
          _buildVehicleStatusCard(
            vehicleName: 'ISUZU D-MAX (1กข 1234)',
            status: VehicleStatus.inUse,
            currentUser: 'นายกิตติ บุญเลิศ (โผ่)',
            timeRange: '08:05 - 16:30 น.',
          ),
        ],
      ],
    );
  }

  Widget _buildRoomStatusCard({
    required String roomName,
    required int capacity,
    required bool isInUse,
    String? currentBookingUser,
    String? timeRange,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isInUse
                ? Colors.red.shade50
                : Colors.green.shade50,
            child: Icon(
              Icons.meeting_room,
              color: isInUse ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isInUse
                      ? 'ผู้ใช้งาน: $currentBookingUser ($timeRange)'
                      : 'ความจุ $capacity คน • พร้อมใช้งาน',
                  style: TextStyle(
                    fontSize: 12,
                    color: isInUse ? Colors.black87 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isInUse ? Colors.red.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isInUse ? 'กำลังใช้งาน' : 'ว่าง',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isInUse ? Colors.red.shade800 : Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleStatusCard({
    required String vehicleName,
    required VehicleStatus status,
    String? currentUser,
    String? timeRange,
  }) {
    Color statusBgColor;
    Color statusTextColor;
    String statusText;

    switch (status) {
      case VehicleStatus.available:
        statusBgColor = Colors.green.shade100;
        statusTextColor = Colors.green.shade800;
        statusText = 'พร้อมใช้งาน';
        break;
      case VehicleStatus.awaitingRelease:
        statusBgColor = Colors.orange.shade100;
        statusTextColor = Colors.orange.shade800;
        statusText = 'รอปล่อยรถ';
        break;
      case VehicleStatus.inUse:
        statusBgColor = Colors.blue.shade100;
        statusTextColor = Colors.blue.shade800;
        statusText = 'กำลังใช้งาน';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.directions_car, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentUser != null
                          ? 'ผู้จอง: $currentUser ($timeRange)'
                          : 'ไม่มีการจองช่วงเวลานี้',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),
          if (status == VehicleStatus.awaitingRelease ||
              status == VehicleStatus.inUse) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == VehicleStatus.awaitingRelease)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(100, 32),
                    ),
                    icon: const Icon(Icons.key, size: 16),
                    label: const Text(
                      'กดปล่อยรถ',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {},
                  ),
                if (status == VehicleStatus.inUse)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(100, 32),
                    ),
                    icon: const Icon(Icons.assignment_turned_in, size: 16),
                    label: const Text(
                      'กดรับรถคืน',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {},
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum VehicleStatus { available, awaitingRelease, inUse }
