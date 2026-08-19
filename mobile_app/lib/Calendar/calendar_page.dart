import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'calendar_model.dart';
import 'calendar_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarService _calendarService = CalendarService();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _isLoading = false;
  List<CalendarEvent> _allEvents = [];
  Map<DateTime, List<CalendarEvent>> _groupedEvents = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchEventsForCurrentView();
  }

  // ฟังก์ชันดึงข้อมูลการจอง โดยดึงข้อมูลครอบคลุมเดือนปัจจุบัน (เผื่อล่วงหน้าและย้อนหลังเล็กน้อย)
  Future<void> _fetchEventsForCurrentView() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ดึงข้อมูลย้อนหลัง 1 เดือน และล่วงหน้า 2 เดือน สำหรับการโหลดแต่ละรอบ
      DateTime startDate = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
      DateTime endDate = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

      List<CalendarEvent> events = await _calendarService.fetchUnifiedEvents(
        startDate,
        endDate,
      );

      _groupEvents(events);

      setState(() {
        _allEvents = events;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // จัดกลุ่ม Event ลงในแต่ละวันที่เกิดเหตุการณ์ (รองรับ Multi-day Booking)
  void _groupEvents(List<CalendarEvent> events) {
    _groupedEvents.clear();

    for (var event in events) {
      // คัดแยกเอาเฉพาะ (ปี-เดือน-วัน) ตัดเวลาออกเพื่อใช้เป็น Key ของ Map
      DateTime startDay = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      DateTime endDay = DateTime(
        event.end.year,
        event.end.month,
        event.end.day,
      );

      // วนลูปใส่วันที่จองตั้งแต่เริ่มจนจบ (เพื่อรองรับการจองรถแบบข้ามวัน)
      DateTime currentDay = startDay;
      while (currentDay.isBefore(endDay) ||
          currentDay.isAtSameMomentAs(endDay)) {
        if (_groupedEvents[currentDay] == null) {
          _groupedEvents[currentDay] = [];
        }
        _groupedEvents[currentDay]!.add(event);

        currentDay = currentDay.add(const Duration(days: 1));
      }
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    // ล้างเวลาออกเพื่อให้ตรงกับ Key ใน Map
    DateTime normalizedDay = DateTime(day.year, day.month, day.day);
    return _groupedEvents[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ปฏิทินการจอง (Read-Only)'),
        backgroundColor: const Color(0xFF00529B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEventsForCurrentView,
          ),
        ],
      ),
      body: Column(
        children: [
          // 🏷️ บาร์แสดงสัญลักษณ์จำแนกประเภท/สถานะการจอง
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            color: Colors.grey.shade100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLegendBadge(Colors.blue, 'ห้องประชุม'),
                  const SizedBox(width: 12),
                  _buildLegendBadge(Colors.orange, 'ยานพาหนะ'),
                  const SizedBox(width: 12),
                  _buildLegendBadge(Colors.green, 'อนุมัติแล้ว'),
                  const SizedBox(width: 12),
                  _buildLegendBadge(Colors.amber, 'รออนุมัติ'),
                ],
              ),
            ),
          ),

          // ส่วนแสดงปฏิทิน
          TableCalendar<CalendarEvent>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              // ดึงข้อมูลใหม่เมื่อเปลี่ยนเดือน (ถ้าจำเป็น)
              _fetchEventsForCurrentView();
            },
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blueGrey,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Color(0xFF00529B),
                shape: BoxShape.circle,
              ),
              markerSize: 6.0,
            ),
            calendarBuilders: CalendarBuilders(
              // ปรับแต่งจุด Marker ใต้วันที่ ให้เป็นสีตามประเภทการจอง (ห้อง/รถ)
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(4).map((event) {
                    // แสดงจุดสูงสุด 4 จุด
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.0),
                      width: 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: event.color,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // ข้อความแสดงสถานะโหลดข้อมูล
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // แสดงรายละเอียดการจองในวันที่เลือก
          Expanded(child: _buildEventList()),
        ],
      ),
    );
  }

  Widget _buildLegendBadge(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Kanit')),
      ],
    );
  }

  Widget _buildEventList() {
    final selectedDate = _selectedDay ?? _focusedDay;
    final selectedEvents = _getEventsForDay(selectedDate);
    final selectedDateText = DateFormat(
      'dd MMMM yyyy',
      'th',
    ).format(selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ส่วนหัวแสดงวันที่เลือก
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          color: const Color(0xFFE8F1F5),
          child: Row(
            children: [
              const Icon(Icons.event_note, color: Color(0xFF00529B), size: 20),
              const SizedBox(width: 8),
              Text(
                'รายการขอใช้งานวันนี้ ($selectedDateText)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003E77),
                  fontFamily: 'Kanit',
                ),
              ),
            ],
          ),
        ),

        // รายการการจอง
        Expanded(
          child: selectedEvents.isEmpty && !_isLoading
              ? const Center(
                  child: Text(
                    'ไม่มีรายการจองในวันนี้',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      fontFamily: 'Kanit',
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: selectedEvents.length,
                  padding: const EdgeInsets.all(12.0),
                  itemBuilder: (context, index) {
                    final event = selectedEvents[index];

                    final timeFormat = DateFormat('HH:mm น.');
                    final dateFormat = DateFormat('yyyy-MM-dd');

                    final isRoom = event.type == 'ROOM';
                    final categoryLabel = isRoom ? 'ห้องประชุม' : 'ยานพาหนะ';
                    final categoryIcon = isRoom
                        ? Icons.meeting_room
                        : Icons.directions_car;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header การ์ด: ไอคอนหมวดหมู่ + ชื่อรายการ + ป้ายกำกับ
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: event.color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    categoryIcon,
                                    color: event.color,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Kanit',
                                        ),
                                      ),
                                      Text(
                                        categoryLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontFamily: 'Kanit',
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
                                    color: event.color,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isRoom ? 'ROOM' : 'VEHICLE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              child: Divider(height: 1),
                            ),

                            // รายละเอียดข้อมูลแบ่งหมวดหมู่ชัดเจน
                            _buildDetailRow(
                              Icons.person_outline,
                              'ผู้จอง/ผู้ปฏิบัติ',
                              event.bookerName,
                              Colors.black87,
                            ),
                            const SizedBox(height: 6),
                            _buildDetailRow(
                              Icons.play_circle_outline,
                              'ในวันที่',
                              '${dateFormat.format(event.start)} T${timeFormat.format(event.start)}',
                              Colors.green.shade700,
                            ),
                            const SizedBox(height: 6),
                            _buildDetailRow(
                              Icons.stop_circle,
                              'ถึงวันที่',
                              '${dateFormat.format(event.end)} T${timeFormat.format(event.end)}',
                              Colors.red.shade700,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          '$label : ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontFamily: 'Kanit',
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
              fontFamily: 'Kanit',
            ),
          ),
        ),
      ],
    );
  }
}
