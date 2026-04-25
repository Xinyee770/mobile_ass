import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import your update page here! Adjust the filename if yours is slightly different.
import 'booking_update.dart';

class BookingRecord extends StatefulWidget {
  const BookingRecord({super.key});

  @override
  State<BookingRecord> createState() => _BookingRecordState();
}

class _BookingRecordState extends State<BookingRecord> {
  final supabase = Supabase.instance.client;
  String _selectedFilter = "All";
  final List<String> _filters = ["All", "CONFIRMED", "CANCELLED", "ATTEND"];

  final Color bgDeep = const Color(0xFF0F0F16);
  final Color cardGrey = const Color(0xFF1E1E2C);
  final Color brandPurple = const Color(0xFF9D59FF);

  Future<List<dynamic>> _fetchBookings() async {
    try {
      final response = await supabase
          .from('booking')
          .select('''
            *,
            payment(status),
            courses(course_name, instructor, instructor_comment)
          ''')
          .order('booking_date', ascending: false);
      return response;
    } catch (e) {
      debugPrint("Fetch Error: $e");
      return [];
    }
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

    // Default to confirmed for new bookings
    return "Confirmed";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Booking History",
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
              future: _fetchBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: brandPurple));
                }
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No bookings found.", style: TextStyle(color: Colors.white54)));
                }

                final allBookings = snapshot.data!;
                final bookings = allBookings.where((b) {
                  if (_selectedFilter == "All") return true;
                  return _calculateStatus(b).toUpperCase() == _selectedFilter.toUpperCase();
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    String displayStatus = _calculateStatus(booking);

                    return _buildBookingCard(
                      courseName: booking['courses']?['course_name'] ?? "Class",
                      instructorName: booking['courses']?['instructor'] ?? "TBA",
                      instructorComment: booking['courses']?['instructor_comment'] ?? "No notes.",
                      date: booking['booking_date']?.toString() ?? "-",
                      time: "${booking['start_time']} - ${booking['end_time']}",
                      location: booking['location']?.toString() ?? "Studio A",
                      status: displayStatus,
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
    required String time,
    required String location,
    required String status,
    required VoidCallback onEdit,
  }) {
    Color statusColor;
    switch (status.toUpperCase()) {
      case "CONFIRMED": statusColor = const Color(0xFF4AC2C5); break;
      case "ATTEND": statusColor = brandPurple; break;
      default: statusColor = const Color(0xFFFF5959);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(status, statusColor),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.edit_note, color: Colors.white70, size: 26),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(courseName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 15,
            runSpacing: 8,
            children: [
              _buildIconText(Icons.calendar_today_outlined, date),
              _buildIconText(Icons.access_time, time),
              _buildIconText(Icons.location_on_outlined, location),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("INSTRUCTOR NOTES", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(instructorComment, style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.white54, size: 18),
                  const SizedBox(width: 6),
                  Text(instructorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                color: isSelected ? brandPurple.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? brandPurple : Colors.transparent),
              ),
              child: Text(filter, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white54, size: 16), const SizedBox(width: 6), Text(text, style: const TextStyle(color: Colors.white54, fontSize: 13))]);
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2))), child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)));
  }
}