import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../Payment_UI/payment.dart';

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
      final filteredData = (data as List).where((course) {
        final inst = course['instructor'];
        return inst != null && inst['is_private'] == false;
      }).toList();

      setState(() {
        publicCourses = List<Map<String, dynamic>>.from(filteredData);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // --- UPDATED: Confirmation Popup with Date & Time ---
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white30)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D59FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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

  // --- Actual Booking Logic ---
  Future<void> _executeBooking() async {
    try {
      final String courseDate = selectedCourseData!['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String startTime = selectedCourseData!['course_start'] ?? "00:00:00";
      final String endTime = selectedCourseData!['course_end'] ?? "01:00:00";

      final response = await supabase.from('booking').insert({
        'user_id': 1,
        'course_id': selectedCourseId,
        'instructor_id': selectedCourseData!['instructor_id'],
        'booking_date': courseDate,
        'start_time': startTime,
        'end_time': endTime,
        'booking_status': 'Confirmed',
      }).select();

      if (response != null && (response as List).isNotEmpty) {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => Payment(bookingId: response[0]['booking_id'])));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("Join a Class", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: isLoading ? const Center(child: CircularProgressIndicator(color: accentColor)) : Padding(
        padding: const EdgeInsets.all(24.0),
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
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: selectedCourseId == null ? null : _confirmJoin,
                child: const Text("JOIN CLASS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
          _infoRow(Icons.group_outlined, "Capacity", "${selectedCourseData!['capacity'] ?? '0'} Participants"),
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
          onChanged: (val) => setState(() {
            selectedCourseId = val;
            selectedCourseData = publicCourses.firstWhere((c) => c['course_id'] == val);
          }),
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