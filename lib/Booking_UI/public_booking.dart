import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../Payment_UI/payment.dart';
import '../services/notification_service.dart';

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
  int userPasses = 0;

  int currentPaxCount = 0;
  bool isCheckingCapacity = false;
  bool hasUserBooked = false;

  final List<Map<String, dynamic>> studios = [
    {'id': 'A', 'name': 'Studio A (Setapak)', 'address': '38-06, Vista Danau Kota, KL'},
    {'id': 'B', 'name': 'Studio B (Bentong)', 'address': 'No.33 Taman Orkid, Bentong'},
    {'id': 'C', 'name': 'Studio C (KL)', 'address': 'Sunway Velocity, KL'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await supabase.from('courses').select('*, instructor(*)');
      final now = DateTime.now();

      final filteredData = (data as List).where((course) {
        final inst = course['instructor'];

        // 1. FILTER: Must have an instructor and instructor must NOT be private
        if (inst == null || inst['is_private'] == true || inst['is_private'] == 1) {
          return false;
        }

        // 2. FILTER: Safely parse date and time to filter out past classes
        final dateStr = course['date'];
        final timeStr = course['course_start'];

        if (dateStr == null) return false;

        try {
          DateTime parsedDate = DateTime.parse(dateStr.toString());
          int hour = 0;
          int minute = 0;

          if (timeStr != null) {
            final timeParts = timeStr.toString().split(':');
            if (timeParts.length >= 2) {
              hour = int.tryParse(timeParts[0]) ?? 0;
              minute = int.tryParse(timeParts[1]) ?? 0;
            }
          }

          DateTime classDateTime = DateTime(
            parsedDate.year,
            parsedDate.month,
            parsedDate.day,
            hour,
            minute,
          );

          // 3. FILTER: If the class time has already passed, hide it
          if (classDateTime.isBefore(now)) {
            return false;
          }
        } catch (e) {
          debugPrint("Date parse error: $e");
          return false;
        }

        return true;
      }).toList();

      final user = supabase.auth.currentUser;
      if (user != null) {
        final profile = await supabase
            .from('profiles')
            .select('passes')
            .eq('id', user.id)
            .single();
        userPasses = profile['passes'] ?? 0;
      }

      setState(() {
        publicCourses = List<Map<String, dynamic>>.from(filteredData);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Load error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkClassCapacity(dynamic courseId, String courseDate) async {
    setState(() {
      isCheckingCapacity = true;
      currentPaxCount = 0;
      hasUserBooked = false;
    });

    try {
      final countResponse = await supabase
          .from('booking')
          .select('booking_id, user_id')
          .eq('course_id', courseId)
          .eq('booking_date', courseDate)
          .neq('booking_status', 'Cancelled');

      final userId = supabase.auth.currentUser?.id;
      bool alreadyBooked = false;

      if (userId != null) {
        alreadyBooked = (countResponse as List).any((booking) => booking['user_id'] == userId);
      }

      setState(() {
        currentPaxCount = (countResponse as List).length;
        hasUserBooked = alreadyBooked;
        isCheckingCapacity = false;
      });
    } catch (e) {
      setState(() => isCheckingCapacity = false);
    }
  }

  void _confirmJoin() {
    String displayDate = "-";
    if (selectedCourseData!['date'] != null) {
      try {
        displayDate = DateFormat('d MMM yyyy').format(DateTime.parse(selectedCourseData!['date']));
      } catch (e) { displayDate = selectedCourseData!['date']; }
    }

    String startTime = selectedCourseData!['course_start']?.toString().substring(0, 5) ?? "-";
    String endTime = selectedCourseData!['course_end']?.toString().substring(0, 5) ?? "-";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Booking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Join '${selectedCourseData!['course_name']}'?", style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            _popupDetailRow(Icons.calendar_today, "Date", displayDate),
            const SizedBox(height: 8),
            _popupDetailRow(Icons.access_time, "Time", "$startTime - $endTime"),
            const SizedBox(height: 8),
            _popupDetailRow(Icons.payments_outlined, "Price", "RM ${selectedCourseData!['course_price']}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white30))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9D59FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(context); _executeBooking(); },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmJoinWithPass() {
    String displayDate = "-";
    if (selectedCourseData!['date'] != null) {
      try { displayDate = DateFormat('d MMM yyyy').format(DateTime.parse(selectedCourseData!['date'])); } catch (_) {}
    }
    String startTime = selectedCourseData!['course_start']?.toString().substring(0, 5) ?? "-";
    String endTime = selectedCourseData!['course_end']?.toString().substring(0, 5) ?? "-";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Use Pass?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Use 1 pass to join '${selectedCourseData!['course_name']}'?", style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            _popupDetailRow(Icons.calendar_today, "Date", displayDate),
            const SizedBox(height: 8),
            _popupDetailRow(Icons.confirmation_number, "Passes Left", "$userPasses"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white30))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(context); _executeBookingWithPass(); },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _popupDetailRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9D59FF), size: 16),
        const SizedBox(width: 10),
        Text("$label: ", style: const TextStyle(color: Colors.white30, fontSize: 13)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _executeBooking() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase.from('booking').insert({
        'user_id': user.id,
        'course_id': selectedCourseId,
        'instructor_id': selectedCourseData!['instructor_id'],
        'booking_date': selectedCourseData!['date'],
        'start_time': selectedCourseData!['course_start'],
        'end_time': selectedCourseData!['course_end'],
        'location': selectedCourseData!['location'] ?? 'Main Studio',
        'booking_status': 'Confirmed',
      }).select();

      if (response.isNotEmpty) {
        DateTime classStart = DateTime.parse("${selectedCourseData!['date']} ${selectedCourseData!['course_start']}");
        await NotificationService().scheduleTaskReminder(
          bookingId: response[0]['booking_id'].toString(),
          taskTitle: "Public Class: ${selectedCourseData!['course_name']}",
          taskDateTime: classStart,
          minutesBefore: 5,
        );
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => Payment(bookingId: response[0]['booking_id'])));
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  Future<void> _executeBookingWithPass() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || userPasses <= 0) return;

      await supabase.from('profiles').update({'passes': userPasses - 1}).eq('id', user.id);

      final response = await supabase.from('booking').insert({
        'user_id': user.id,
        'course_id': selectedCourseId,
        'instructor_id': selectedCourseData!['instructor_id'],
        'booking_date': selectedCourseData!['date'],
        'start_time': selectedCourseData!['course_start'],
        'end_time': selectedCourseData!['course_end'],
        'location': selectedCourseData!['location'],
        'booking_status': 'Confirmed',
      }).select();

      setState(() { userPasses -= 1; hasUserBooked = true; });
      _showSnackBar("Booked successfully using pass!", Colors.green);
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);
    int maxCapacity = int.tryParse(selectedCourseData?['capacity']?.toString() ?? '20') ?? 20;
    bool isFull = currentPaxCount >= maxCapacity;
    bool canBook = selectedCourseId != null && !isCheckingCapacity && !isFull && !hasUserBooked;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("Join a Class", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), iconTheme: const IconThemeData(color: Colors.white)),
      body: isLoading ? const Center(child: CircularProgressIndicator(color: accentColor)) : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Select Session", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 12),
                    _buildDropdownBox(accentColor),
                    const SizedBox(height: 24),
                    if (selectedCourseData != null) ...[
                      const Text("Class Summary", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 12),
                      _buildConsolidatedInfoBox(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(canBook, accentColor, isFull),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool canBook, Color accentColor, bool isFull) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: (canBook && userPasses > 0) ? Colors.green : const Color(0xFF2A2A3A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: (canBook && userPasses > 0) ? _confirmJoinWithPass : null,
            child: Text(hasUserBooked ? "ALREADY BOOKED" : (userPasses > 0 ? "JOIN WITH PASSES" : "NO PASSES AVAILABLE"), style: TextStyle(color: (canBook && userPasses > 0) ? Colors.white : Colors.white30, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: canBook ? accentColor : const Color(0xFF2A2A3A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: canBook ? _confirmJoin : null,
            child: isCheckingCapacity ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(hasUserBooked ? "ALREADY BOOKED" : (isFull ? "CLASS FULL" : "JOIN CLASS"), style: TextStyle(color: canBook ? Colors.white : Colors.white30, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildConsolidatedInfoBox() {
    String displayDate = "-";
    try { displayDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.parse(selectedCourseData!['date'])); } catch (_) { displayDate = selectedCourseData!['date'] ?? "-"; }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A24), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        children: [
          _infoRow(Icons.person_outline, "Instructor", selectedCourseData!['instructor']?['instructor_name'] ?? "TBA"),
          const SizedBox(height: 16),
          _infoRow(Icons.payments_outlined, "Price", "RM ${selectedCourseData!['course_price']}"),
          const SizedBox(height: 16),
          _infoRow(Icons.flash_on_outlined, "Level", selectedCourseData!['level'] ?? "All Levels"),
          const SizedBox(height: 16),
          _infoRow(Icons.calendar_today_outlined, "Date", displayDate),
          const SizedBox(height: 16),
          _infoRow(Icons.access_time, "Time", "${selectedCourseData!['course_start']?.substring(0, 5)} - ${selectedCourseData!['course_end']?.substring(0, 5)}"),
          const SizedBox(height: 16),
          _infoRow(Icons.location_on_outlined, "Location", selectedCourseData!['location'] ?? "Main Studio"),
          const Divider(height: 32, color: Colors.white10),
          _buildCapacityIndicator(),
        ],
      ),
    );
  }

  Widget _buildCapacityIndicator() {
    int maxCapacity = int.tryParse(selectedCourseData!['capacity']?.toString() ?? '20') ?? 20;
    return Row(
      children: [
        Icon(Icons.group_outlined, color: currentPaxCount >= maxCapacity ? Colors.redAccent : const Color(0xFF9D59FF), size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Availability", style: TextStyle(color: Colors.white30, fontSize: 11)),
            if (isCheckingCapacity) const Text("Checking...", style: TextStyle(color: Colors.white54, fontSize: 13))
            else Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("$currentPaxCount / $maxCapacity Booked", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(currentPaxCount >= maxCapacity ? "Full" : "${maxCapacity - currentPaxCount} slots left", style: TextStyle(color: currentPaxCount >= maxCapacity ? Colors.redAccent : const Color(0xFF57C5B6), fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _buildDropdownBox(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A24), borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: selectedCourseId, dropdownColor: const Color(0xFF1E1E2C), isExpanded: true, icon: Icon(Icons.keyboard_arrow_down, color: accentColor),
          hint: const Text("Choose a class", style: TextStyle(color: Colors.white30, fontSize: 14)),
          items: publicCourses.map((c) => DropdownMenuItem(value: c['course_id'], child: Text(c['course_name'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 15)))).toList(),
          onChanged: (val) {
            setState(() {
              selectedCourseId = val;
              selectedCourseData = publicCourses.firstWhere((c) => c['course_id'] == val);
            });
            _checkClassCapacity(val, selectedCourseData!['date']);
          },
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF9D59FF), size: 20),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 11)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    ]);
  }

  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}