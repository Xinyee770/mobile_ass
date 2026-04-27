import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Payment_UI/payment.dart';

class Classes extends StatefulWidget {
  const Classes({super.key});

  @override
  State<Classes> createState() => _ClassesState();
}

class _ClassesState extends State<Classes> {
  final supabase = Supabase.instance.client;

  final Color bg = const Color(0xFF0F0F16);
  final Color card = const Color(0xFF1E1E2C);
  final Color purple = const Color(0xFF9D59FF);
  final Color textGrey = const Color(0xFF9A9AAB);

  bool isLoading = true;
  List<Map<String, dynamic>> classes = [];

  @override
  void initState() {
    super.initState();
    loadClasses();
  }

  Future<void> loadClasses() async {
    try {
      final data = await supabase
          .from('courses')
          .select('*, instructor(*)')
          .order('date', ascending: true);

      setState(() {
        classes = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      showSnack("Failed to load classes: $e", true);
    }
  }

  void showSnack(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> buyClass(Map<String, dynamic> course) async {
    try {
      final response = await supabase.from('booking').insert({
        'user_id': 1,
        'course_id': course['course_id'],
        'instructor_id': course['instructor_id'],
        'booking_date': course['date'],
        'start_time': course['course_start'],
        'end_time': course['course_end'],
        'location': course['location'],
        'booking_status': 'Pending',
      }).select();

      if (response.isEmpty) {
        showSnack("Booking failed. Please try again.", true);
        return;
      }

      final int bookingId = response[0]['booking_id'];

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Payment(bookingId: bookingId),
        ),
      );
    } catch (e) {
      showSnack("Cannot buy class: $e", true);
    }
  }

  void showClassDetail(Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course['course_name']?.toString() ?? 'Dance Class',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              detailRow(Icons.location_on, "Location", course['location']),
              detailRow(Icons.calendar_today, "Date", course['date']),
              detailRow(
                Icons.access_time,
                "Time",
                "${course['course_start']} - ${course['course_end']}",
              ),
              detailRow(Icons.trending_up, "Level", course['level']),
              detailRow(Icons.people, "Capacity", course['capacity']),
              detailRow(
                Icons.person,
                "Instructor",
                course['instructor']?['instructor_name'] ??
                    course['instructor_id'],
              ),
              const SizedBox(height: 18),
              Text(
                "RM ${course['course_price'] ?? 0}",
                style: TextStyle(
                  color: purple,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    buyClass(course);
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text(
                    "Buy Class",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget detailRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: purple, size: 20),
          const SizedBox(width: 10),
          Text("$label: ", style: TextStyle(color: textGrey)),
          Expanded(
            child: Text(
              value?.toString() ?? "-",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget classCard(Map<String, dynamic> course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.music_note_rounded, color: purple, size: 34),
          const SizedBox(height: 12),
          Text(
            course['course_name']?.toString() ?? 'Dance Class',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          detailRow(Icons.location_on, "Studio", course['location']),
          detailRow(Icons.calendar_today, "Date", course['date']),
          detailRow(
            Icons.access_time,
            "Time",
            "${course['course_start']} - ${course['course_end']}",
          ),
          detailRow(Icons.trending_up, "Level", course['level']),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                "RM ${course['course_price'] ?? 0}",
                style: TextStyle(
                  color: purple,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: purple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => showClassDetail(course),
                child: const Text("View"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => buyClass(course),
                child: const Text("Buy"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          "Dance Classes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: purple))
          : classes.isEmpty
          ? Center(
        child: Text(
          "No classes available",
          style: TextStyle(color: textGrey),
        ),
      )
          : RefreshIndicator(
        onRefresh: loadClasses,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              "Choose Your Dance Class",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Find a class, book your spot, and complete payment.",
              style: TextStyle(color: textGrey),
            ),
            const SizedBox(height: 20),
            ...classes.map(classCard).toList(),
          ],
        ),
      ),
    );
  }
}