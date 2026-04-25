import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PublicBooking extends StatefulWidget {
  const PublicBooking({super.key});

  @override
  State<PublicBooking> createState() => _PublicBookingPageState();
}

class _PublicBookingPageState extends State<PublicBooking> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> publicCourses = [];
  dynamic selectedCourseId;
  Map<String, dynamic>? selectedCourseData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await supabase.from('courses').select('*, instructor(*)');
      final filteredData = (data as List).where((course) {
        final inst = course['instructor'];
        return inst != null && (inst['is_private'] == false || inst['is_private'] == null);
      }).toList();

      setState(() {
        publicCourses = List<Map<String, dynamic>>.from(filteredData);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitBooking() async {
    if (selectedCourseData == null) return;

    try {
      String rawTime = selectedCourseData!['schedule']?.toString() ?? "14:00:00";
      String startTime = rawTime;

      // Convert "2pm" style to "14:00:00"
      if (rawTime.toLowerCase().contains('pm')) {
        int hour = int.parse(rawTime.replaceAll(RegExp(r'[^0-9]'), ''));
        startTime = "${hour + 12}:00:00";
      } else if (rawTime.toLowerCase().contains('am')) {
        int hour = int.parse(rawTime.replaceAll(RegExp(r'[^0-9]'), ''));
        startTime = "${hour.toString().padLeft(2, '0')}:00:00";
      }

      // 🚀 FIX: Calculate end_time (Adding 1 hour)
      final DateFormat df = DateFormat("HH:mm:ss");
      DateTime startDT = df.parse(startTime);
      String endTime = df.format(startDT.add(const Duration(hours: 1)));

      await supabase.from('booking').insert({
        'user_id': 1,
        'course_id': selectedCourseId,
        'instructor_id': selectedCourseData!['instructor_id'],
        'booking_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'start_time': startTime,
        'end_time': endTime, // Now sending valid end_time
        'booking_status': 'Confirmed',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined Successfully!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Booking Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("Join a Class")),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Available Classes", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildDropdown(),
            const SizedBox(height: 30),
            if (selectedCourseData != null) _buildInfoCard(),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: selectedCourseId == null ? null : _submitBooking,
                child: const Text("JOIN CLASS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: selectedCourseId,
          hint: const Text("Tap to select a class", style: TextStyle(color: Colors.white30)),
          dropdownColor: const Color(0xFF1E1E2C),
          isExpanded: true,
          items: publicCourses.map((c) => DropdownMenuItem(value: c['course_id'], child: Text(c['course_name'] ?? "", style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: (val) => setState(() {
            selectedCourseId = val;
            selectedCourseData = publicCourses.firstWhere((c) => c['course_id'] == val);
          }),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF1A1A24), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _row(Icons.person_outline, "Instructor", selectedCourseData!['instructor']?['instructor_name'] ?? "TBA"),
          const SizedBox(height: 20),
          _row(Icons.calendar_today_outlined, "Schedule", selectedCourseData!['schedule'] ?? "-"),
          const SizedBox(height: 20),
          _row(Icons.flash_on_outlined, "Difficulty", selectedCourseData!['difficulty'] ?? "Beginner"),
          const SizedBox(height: 20),
          _row(Icons.group_outlined, "Capacity", "${selectedCourseData!['capacity'] ?? '50'} Pax"),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String val) {
    return Row(children: [
      Icon(icon, color: Colors.white30), const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 12)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ])
    ]);
  }
}