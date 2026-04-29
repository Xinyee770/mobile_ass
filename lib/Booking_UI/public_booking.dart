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
        if (inst == null || inst['is_private'] == true) return false;

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

          if (classDateTime.isBefore(now)) return false;
        } catch (e) {
          debugPrint("Date parse error: $e");
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
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkClassCapacity(dynamic courseId, String courseDate) async {
    setState(() {
      isCheckingCapacity = true;
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
      if (userId != null) {
        hasUserBooked = (countResponse as List).any((booking) => booking['user_id'] == userId);
      }

      setState(() {
        currentPaxCount = (countResponse as List).length;
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
            onPressed: () {
              Navigator.pop(context);
              _executeBooking();
            },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmJoinWithPass() {
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
        title: const Text("Use Pass?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Use 1 pass to join '${selectedCourseData!['course_name']}'?", style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            _popupDetailRow(Icons.calendar_today, "Date", displayDate),
            const SizedBox(height: 8),
            _popupDetailRow(Icons.access_time, "Time", "$startTime - $endTime"),
            const SizedBox(height: 8),
            _popupDetailRow(Icons.confirmation_number, "Passes Left", "$userPasses"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white30))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Navigator.pop(context);
              _executeBookingWithPass();
            },
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

  // --- JOIN VIA PAYMENT ---
  Future<void> _executeBooking() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final String courseDate = selectedCourseData!['date'];
      final String startTime = selectedCourseData!['course_start'];

      final response = await supabase.from('booking').insert({
        'user_id': user.id,
        'course_id': selectedCourseId,
        'instructor_id': selectedCourseData!['instructor_id'],
        'booking_date': courseDate,
        'start_time': startTime,
        'end_time': selectedCourseData!['course_end'],
        'location': selectedCourseData!['location'] ?? 'Main Studio',
        'booking_status': 'Confirmed',
      }).select();

      if (response.isNotEmpty) {
        // --- SCHEDULE NOTIFICATION: 30 MIN BEFORE ---
        try {
          DateTime classDateTime = DateTime.parse("$courseDate $startTime");
          await NotificationService().scheduleTaskReminder(
            bookingId: response[0]['booking_id'].toString(),
            taskTitle: "Class Reminder: ${selectedCourseData!['course_name']}",
            taskDateTime: classDateTime,
            minutesBefore: 30, // CHANGED FROM 5 TO 30
          );
        } catch (e) { debugPrint("Notification Error: $e"); }

        if (!mounted) return;
        setState(() => hasUserBooked = true);
        Navigator.push(context, MaterialPageRoute(builder: (context) => Payment(bookingId: response[0]['booking_id'])));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // --- JOIN VIA PASS ---
  Future<void> _executeBookingWithPass() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || userPasses <= 0) return;

      final String courseDate = selectedCourseData!['date'];
      final String startTime = selectedCourseData!['course_start'];

      await supabase.from('profiles').update({'passes': userPasses - 1}).eq('id', user.id);

      final response = await supabase.from('booking').insert({
        'user_id': user.id,
        'course_id': selectedCourseId,
        'instructor_id': selectedCourseData!['instructor_id'],
        'booking_date': courseDate,
        'start_time': startTime,
        'end_time': selectedCourseData!['course_end'],
        'location': selectedCourseData!['location'],
        'booking_status': 'Confirmed',
      }).select();

      if (response.isNotEmpty) {
        // --- SCHEDULE NOTIFICATION: 30 MIN BEFORE ---
        try {
          DateTime classDateTime = DateTime.parse("$courseDate $startTime");
          await NotificationService().scheduleTaskReminder(
            bookingId: response[0]['booking_id'].toString(),
            taskTitle: "Class Reminder: ${selectedCourseData!['course_name']}",
            taskDateTime: classDateTime,
            minutesBefore: 30, // CHANGED FROM 5 TO 30
          );
        } catch (e) { debugPrint("Notification Error: $e"); }
      }

      setState(() {
        userPasses -= 1;
        hasUserBooked = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booked successfully using pass!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _showAddressPopup(String studioName) {
    final studio = studios.firstWhere(
          (s) => studioName.toUpperCase().contains(s['id']),
      orElse: () => {'address': 'Full address not found.'},
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(studioName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(studio['address'], style: const TextStyle(color: Colors.white, fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE", style: TextStyle(color: Color(0xFF9D59FF)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);
    int maxCapacity = int.tryParse(selectedCourseData?['capacity']?.toString() ?? '20') ?? 20;
    bool isFull = currentPaxCount >= maxCapacity;
    bool canBook = selectedCourseId != null && !isCheckingCapacity && !isFull && !hasUserBooked;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Join a Class", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator(color: accentColor)) : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (canBook && userPasses > 0) ? Colors.green : const Color(0xFF2A2A3A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (canBook && userPasses > 0) ? _confirmJoinWithPass : null,
                child: Text(
                  hasUserBooked ? "ALREADY BOOKED" : (userPasses > 0 ? "JOIN WITH PASSES" : "NO PASSES AVAILABLE"),
                  style: TextStyle(color: (canBook && userPasses > 0) ? Colors.white : Colors.white30, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: canBook ? accentColor : const Color(0xFF2A2A3A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                onPressed: canBook ? _confirmJoin : null,
                child: isCheckingCapacity
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                    hasUserBooked ? "ALREADY BOOKED" : (isFull ? "CLASS FULL" : "JOIN CLASS"),
                    style: TextStyle(color: canBook ? Colors.white : Colors.white30, fontWeight: FontWeight.bold, fontSize: 16)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsolidatedInfoBox() {
    String displayDate = "-";
    if (selectedCourseData!['date'] != null) {
      try { displayDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.parse(selectedCourseData!['date'])); } catch (e) { displayDate = selectedCourseData!['date']; }
    }
    String startTime = selectedCourseData!['course_start']?.toString().substring(0, 5) ?? "-";
    String endTime = selectedCourseData!['course_end']?.toString().substring(0, 5) ?? "-";
    String price = selectedCourseData!['course_price']?.toString() ?? "0.00";
    String studioName = selectedCourseData!['location'] ?? "Main Studio";
    int maxCapacity = int.tryParse(selectedCourseData!['capacity']?.toString() ?? '20') ?? 20;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A24), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        children: [
          _infoRow(Icons.person_outline, "Instructor", selectedCourseData!['instructor']?['instructor_name'] ?? "TBA"),
          const SizedBox(height: 16),
          _infoRow(Icons.payments_outlined, "Price", "RM $price"),
          const SizedBox(height: 16),
          _infoRow(Icons.flash_on_outlined, "Level", selectedCourseData!['level'] ?? "All Levels"),
          const SizedBox(height: 16),
          _infoRow(Icons.calendar_today_outlined, "Date", displayDate),
          const SizedBox(height: 16),
          _infoRow(Icons.access_time, "Time", "$startTime - $endTime"),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _showAddressPopup(studioName),
            borderRadius: BorderRadius.circular(8),
            child: Row(children: [Expanded(child: _infoRow(Icons.location_on_outlined, "Location", studioName)), const Icon(Icons.info_outline, color: Colors.white24, size: 16)]),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          Row(
              children: [
                Icon(Icons.group_outlined, color: currentPaxCount >= maxCapacity ? Colors.redAccent : const Color(0xFF9D59FF), size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Availability", style: TextStyle(color: Colors.white30, fontSize: 11)),
                        const SizedBox(height: 4),
                        isCheckingCapacity
                            ? const Text("Checking slots...", style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic))
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("$currentPaxCount / $maxCapacity Booked", style: TextStyle(color: currentPaxCount >= maxCapacity ? Colors.redAccent : Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(currentPaxCount >= maxCapacity ? "Full" : "${maxCapacity - currentPaxCount} slots left", style: TextStyle(color: currentPaxCount >= maxCapacity ? Colors.redAccent : const Color(0xFF57C5B6), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ]
                  ),
                ),
              ]
          )
        ],
      ),
    );
  }

  Widget _buildDropdownBox(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF1A1A24), borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: selectedCourseId,
          hint: const Text("Tap to choose a class", style: TextStyle(color: Colors.white30, fontSize: 14)),
          dropdownColor: const Color(0xFF1E1E2C),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: accentColor),
          items: publicCourses.map((c) => DropdownMenuItem(value: c['course_id'], child: Text(c['course_name'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 15)))).toList(),
          onChanged: (val) {
            setState(() {
              selectedCourseId = val;
              selectedCourseData = publicCourses.firstWhere((c) => c['course_id'] == val);
            });
            if (selectedCourseData != null) {
              String classDate = selectedCourseData!['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
              _checkClassCapacity(val, classDate);
            }
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
}