import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final supabase = Supabase.instance.client;

  List<dynamic> upcomingBookings = [];
  List<dynamic> pastBookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      // Fetch bookings for the current user (user_id 1 based on your booking code)
      // We join the courses and instructor tables to get their names!
      final response = await supabase
          .from('booking')
          .select('*, courses(course_name), instructor(instructor_name)')
          .eq('user_id', 1)
          .order('booking_date', ascending: true)
          .order('start_time', ascending: true);

      final now = DateTime.now();
      List<dynamic> upcoming = [];
      List<dynamic> past = [];

      for (var booking in response as List) {
        // Combine date and time to figure out if it has passed
        final dateString = booking['booking_date'];
        final timeString = booking['start_time'];

        // Parse "YYYY-MM-DD" and "HH:MM:SS"
        final DateTime bookingDate = DateTime.parse(dateString);
        final List<String> timeParts = timeString.toString().split(':');
        final DateTime fullBookingDateTime = DateTime(
          bookingDate.year,
          bookingDate.month,
          bookingDate.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        if (fullBookingDateTime.isAfter(now)) {
          upcoming.add(booking);
        } else {
          past.add(booking);
        }
      }

      // Reverse past bookings so the most recent ones are at the top
      past = past.reversed.toList();

      setState(() {
        upcomingBookings = upcoming;
        pastBookings = past;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Error: $e");
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading timetable: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);
    const bgColor = Color(0xFF0F0F16);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          title: const Text("My Timetable", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: accentColor,
            labelColor: accentColor,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Past"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: accentColor))
            : TabBarView(
          children: [
            _buildBookingList(upcomingBookings, isUpcoming: true),
            _buildBookingList(pastBookings, isUpcoming: false),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList(List<dynamic> bookings, {required bool isUpcoming}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isUpcoming ? Icons.calendar_today_outlined : Icons.history, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? "No upcoming classes!" : "No past classes yet.",
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];

        // Handle potential nulls safely if the database join fails
        final courseName = booking['courses']?['course_name'] ?? 'Unknown Course';
        final instructorName = booking['instructor']?['instructor_name'] ?? 'Unknown Instructor';
        final location = booking['location'] ?? 'Unknown Location';

        final DateTime date = DateTime.parse(booking['booking_date']);
        final String startTime = booking['start_time'].toString().substring(0, 5); // Just HH:mm

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isUpcoming ? const Color(0xFF9D59FF).withOpacity(0.3) : Colors.transparent),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Side: Date and Time Badge
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isUpcoming ? const Color(0xFF9D59FF).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(DateFormat('MMM').format(date).toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(DateFormat('dd').format(date), style: TextStyle(color: isUpcoming ? const Color(0xFF9D59FF) : Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(startTime, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right Side: Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(courseName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.person_outline, instructorName),
                    const SizedBox(height: 4),
                    _buildInfoRow(Icons.location_on_outlined, location),
                    const SizedBox(height: 12),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUpcoming ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        booking['booking_status'] ?? (isUpcoming ? 'Confirmed' : 'Completed'),
                        style: TextStyle(color: isUpcoming ? Colors.greenAccent : Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14))),
      ],
    );
  }
}