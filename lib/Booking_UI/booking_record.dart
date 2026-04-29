import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_update.dart';

class BookingRecord extends StatefulWidget {
  const BookingRecord({super.key});

  @override
  State<BookingRecord> createState() => _PrivateBookingRecordState();
}

class _PrivateBookingRecordState extends State<BookingRecord> {
  final supabase = Supabase.instance.client;

  // Filters
  String _selectedFilter = "All";
  final List<String> _filters = ["All", "CONFIRMED", "CANCELLED", "ATTEND", "MISSED"];

  // Sort Options
  String _selectedSort = "Nearest Day";
  final List<String> _sortOptions = ["Nearest Day", "Time", "Instructor (A-Z)", "Location"];

  final Color bgColor = const Color(0xFF0F0F16);
  final Color cardColor = const Color(0xFF1A1A24);
  final Color textGrey = const Color(0xFF8B8B9E);
  final Color brandPurple = const Color(0xFF9D59FF);

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return "-";
    try {
      return time.substring(0, 5);
    } catch (e) {
      return time;
    }
  }

  Future<List<dynamic>> _fetchPrivateBookings() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final response = await supabase
          .from('booking')
          .select('''
          *,
          payment(status),
          courses(course_name),
          instructor(*)
        ''')
          .eq('user_id', user.id)
          .order('booking_date', ascending: false);

      // --- FIX: Convert read-only maps to editable maps so we can update the status locally ---
      final privateBookings = (response as List)
          .map((b) => Map<String, dynamic>.from(b))
          .where((booking) {
        final inst = booking['instructor'];
        return inst != null && inst['is_private'] == true;
      }).toList();

      final now = DateTime.now();

      // --- AUTO-CONVERT UNATTENDED 'CONFIRMED' CLASSES TO 'MISSED' ---
      for (var booking in privateBookings) {
        if (booking['booking_status'].toString().toUpperCase() == 'CONFIRMED') {
          final dateStr = booking['booking_date'];
          final endTimeStr = booking['end_time'];

          if (dateStr != null && endTimeStr != null) {
            try {
              DateTime parsedDate = DateTime.parse(dateStr.toString());
              int hour = 0;
              int minute = 0;

              final timeParts = endTimeStr.toString().split(':');
              if (timeParts.length >= 2) {
                hour = int.tryParse(timeParts[0]) ?? 0;
                minute = int.tryParse(timeParts[1]) ?? 0;
              }

              DateTime classEndDateTime = DateTime(
                parsedDate.year,
                parsedDate.month,
                parsedDate.day,
                hour,
                minute,
              );

              if (now.isAfter(classEndDateTime)) {

                booking['booking_status'] = 'MISSED';

                final bookingId = booking['booking_id'] ?? booking['id'];
                if (bookingId != null) {
                  supabase
                      .from('booking')
                      .update({'booking_status': 'MISSED'})
                      .eq('booking_id', bookingId)
                      .catchError((e) => debugPrint("Error updating DB to missed: $e"));
                }
              }
            } catch (e) {
              debugPrint("Date parse error for missed logic: $e");
            }
          }
        }
      }

      return privateBookings;
    } catch (e) {
      debugPrint("Fetch History Error: $e");
      return [];
    }
  }

  void _sortBookings(List<dynamic> list) {
    switch (_selectedSort) {
      case "Nearest Day":
        list.sort((a, b) => (a['booking_date'] ?? "").compareTo(b['booking_date'] ?? ""));
        break;
      case "Time":
        list.sort((a, b) => (a['start_time'] ?? "").compareTo(b['start_time'] ?? ""));
        break;
      case "Instructor (A-Z)":
        list.sort((a, b) {
          String nameA = a['instructor']?['instructor_name'] ?? "ZZZ";
          String nameB = b['instructor']?['instructor_name'] ?? "ZZZ";
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        });
        break;
      case "Location":
        list.sort((a, b) => (a['location'] ?? "").compareTo(b['location'] ?? ""));
        break;
    }
  }

  String _calculateStatus(dynamic booking) {
    String rawBookingStatus = (booking['booking_status'] ?? "").toString().toUpperCase();

    if (rawBookingStatus == 'CANCELLED') return "Cancelled";
    if (rawBookingStatus == 'ATTENDED' || rawBookingStatus == 'DONE') return "Attend";
    if (rawBookingStatus == 'MISSED') return "Missed";

    return "Confirmed";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Private History",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildSortSection(),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _fetchPrivateBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: brandPurple));
                }

                List<dynamic> bookings = snapshot.data ?? [];

                // Filter
                bookings = bookings.where((b) {
                  if (_selectedFilter == "All") return true;
                  return _calculateStatus(b).toUpperCase() == _selectedFilter.toUpperCase();
                }).toList();

                // Sort
                _sortBookings(bookings);

                if (bookings.isEmpty) {
                  return Center(child: Text("No matching records.", style: TextStyle(color: textGrey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return _buildBookingCard(
                      courseName: booking['courses']?['course_name'] ?? "Private Lesson",
                      instructorName: booking['instructor']?['instructor_name'] ?? "TBA",
                      instructorComment: "No notes available.",
                      date: booking['booking_date']?.toString() ?? "-",
                      startTime: _formatTime(booking['start_time']),
                      endTime: _formatTime(booking['end_time']),
                      location: booking['location']?.toString() ?? "Private Studio",
                      status: _calculateStatus(booking),
                      onEdit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BookingUpdate(booking: booking)),
                        ).then((_) => setState(() {}));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.sort, color: brandPurple, size: 18),
          const SizedBox(width: 8),
          Text("Sort by:", style: TextStyle(color: textGrey, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sortOptions.map((option) {
                  bool isSelected = _selectedSort == option;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSort = option),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: isSelected ? brandPurple : Colors.white10),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected ? brandPurple.withOpacity(0.1) : Colors.transparent,
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          color: isSelected ? Colors.white : textGrey,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: _filters.map((filter) {
          bool isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? brandPurple.withOpacity(0.15) : cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? brandPurple : Colors.transparent),
              ),
              child: Text(filter, style: TextStyle(color: isSelected ? Colors.white : textGrey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBookingCard({
    required String courseName,
    required String instructorName,
    required String instructorComment,
    required String date,
    required String startTime,
    required String endTime,
    required String location,
    required String status,
    required VoidCallback onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDynamicStatusBadge(status),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.edit_note, color: textGrey, size: 28),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(courseName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: textGrey, size: 16),
              const SizedBox(width: 8),
              Text(date, style: TextStyle(color: textGrey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time, color: textGrey, size: 16),
              const SizedBox(width: 8),
              Text("$startTime - $endTime", style: TextStyle(color: textGrey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: textGrey, size: 16),
              const SizedBox(width: 8),
              Text(location, style: TextStyle(color: textGrey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A2A35), thickness: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("NOTES", style: TextStyle(color: textGrey.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(instructorComment, style: TextStyle(color: textGrey, fontSize: 13, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Icon(Icons.person_outline, color: textGrey, size: 16),
                  const SizedBox(width: 6),
                  Text(instructorName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDynamicStatusBadge(String status) {
    Color badgeBgColor;
    Color badgeTextColor;
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        badgeBgColor = const Color(0xFF183336);
        badgeTextColor = const Color(0xFF4DD0E1);
        break;
      case 'CANCELLED':
        badgeBgColor = const Color(0xFF3E1F1F);
        badgeTextColor = const Color(0xFFE57373);
        break;
      case 'ATTEND':
        badgeBgColor = brandPurple.withOpacity(0.15);
        badgeTextColor = brandPurple;
        break;
      case 'MISSED':
        badgeBgColor = const Color(0xFF422C1A);
        badgeTextColor = const Color(0xFFFFB74D);
        break;
      default:
        badgeBgColor = const Color(0xFF2A2A35);
        badgeTextColor = textGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: badgeTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}