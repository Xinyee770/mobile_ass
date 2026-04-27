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
  String _selectedFilter = "All";
  final List<String> _filters = ["All", "CONFIRMED", "CANCELLED", "ATTEND"];

  final Color bgColor = const Color(0xFF0F0F16);
  final Color cardColor = const Color(0xFF1A1A24);
  final Color textGrey = const Color(0xFF8B8B9E);
  final Color brandPurple = const Color(0xFF9D59FF);

  // Helper to format time strings (HH:mm:ss -> HH:mm)
  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return "-";
    try {
      return time.substring(0, 5);
    } catch (e) {
      return time;
    }
  }

  Future<List<dynamic>> _fetchPrivateBookings() async {
    final response = await supabase
        .from('booking')
        .select('''
          *,
          payment(status),
          courses(course_name),
          instructor(*)
        ''')
        .order('booking_date', ascending: false);

    final privateBookings = (response as List).where((booking) {
      final inst = booking['instructor'];
      return inst != null && inst['is_private'] == true;
    }).toList();

    return privateBookings;
  }

  String _calculateStatus(dynamic booking) {
    String rawBookingStatus = (booking['booking_status'] ?? "").toString().toLowerCase();
    if (rawBookingStatus == 'cancelled') return "Cancelled";
    if (rawBookingStatus == 'attended' || rawBookingStatus == 'done') return "Attend";

    final paymentData = booking['payment'];
    if (paymentData != null) {
      String? pStatus;
      if (paymentData is List && paymentData.isNotEmpty) {
        pStatus = paymentData[0]['status']?.toString().toLowerCase();
      } else if (paymentData is Map) {
        pStatus = paymentData['status']?.toString().toLowerCase();
      }
      if (pStatus == 'paid') return "Confirmed";
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _fetchPrivateBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: brandPurple));
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Database Error", style: TextStyle(color: textGrey)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("No private bookings found.", style: TextStyle(color: textGrey)));
                }

                final bookings = snapshot.data!.where((b) {
                  if (_selectedFilter == "All") return true;
                  return _calculateStatus(b).toUpperCase() == _selectedFilter.toUpperCase();
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final courseData = booking['courses'];
                    final instructorData = booking['instructor'];

                    return _buildBookingCard(
                      courseName: courseData?['course_name'] ?? "Private Lesson",
                      instructorName: instructorData?['instructor_name'] ?? "TBA",
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

          // DATE ROW
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: textGrey, size: 16),
              const SizedBox(width: 8),
              Text(date, style: TextStyle(color: textGrey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10), // Gap between date and time

          // TIME ROW (Now under date)
          Row(
            children: [
              Icon(Icons.access_time, color: textGrey, size: 16),
              const SizedBox(width: 8),
              Text("$startTime - $endTime", style: TextStyle(color: textGrey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),

          // LOCATION ROW
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

  Widget _buildFilterSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      default:
        badgeBgColor = const Color(0xFF2A2A35);
        badgeTextColor = textGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: badgeTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}