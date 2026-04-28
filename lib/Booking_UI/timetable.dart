import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final supabase = Supabase.instance.client;
  List<dynamic> allBookings = [];
  bool isLoading = true;
  String selectedDay = DateFormat('EEE').format(DateTime.now()).toUpperCase();

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  // --- DATABASE: Fetch dynamic records for the logged-in user ---
  Future<void> _fetchBookings() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Filter by the dynamic UUID (user.id)
      final response = await supabase
          .from('booking')
          .select('*, courses(course_name), instructor(instructor_name)')
          .eq('user_id', user.id)
          .order('start_time', ascending: true);

      setState(() {
        allBookings = response as List;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Error: $e");
      setState(() => isLoading = false);
    }
  }

  // --- PDF: Dynamic Generation based on your actual records ---
  Future<void> _generatePDF() async {
    final pdf = pw.Document();

    // Sort bookings by date for the PDF report
    final sortedBookings = List.from(allBookings);
    sortedBookings.sort((a, b) => (a['booking_date'] ?? "").compareTo(b['booking_date'] ?? ""));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("My Class Timetable",
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Time', 'Course', 'Instructor', 'Location'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
              cellHeight: 30,
              data: sortedBookings.map((booking) {
                return [
                  booking['booking_date'] ?? "-",
                  "${_safeTime(booking['start_time'])} - ${_safeTime(booking['end_time'])}",
                  booking['courses']?['course_name'] ?? "Class",
                  booking['instructor']?['instructor_name'] ?? "TBA",
                  booking['location'] ?? "Studio",
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // Helper to prevent crashes if time is null or short
  String _safeTime(dynamic time) {
    if (time == null || time.toString().length < 5) return "--:--";
    return time.toString().substring(0, 5);
  }

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("My Timetable", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text("Note:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildInfoItem("1.", "You can download your actual booking history as a PDF."),
            const SizedBox(height: 12),
            _buildInfoItem("2.", "Only confirmed and upcoming classes are shown."),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D59FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _generatePDF,
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text("DOWNLOAD PDF RECORD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);
    const bgColor = Color(0xFF0F0F16);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text("Class Timetable", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _showInfoSheet, icon: const Icon(Icons.info_outline, color: Colors.white54)),
        ],
      ),
      body: Column(
        children: [
          _buildDaySelector(accentColor),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: accentColor))
                : _buildTimelineContent(accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(Color accent) {
    List<String> days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((day) {
          bool isSelected = day == selectedDay;
          return GestureDetector(
            onTap: () => setState(() => selectedDay = day),
            child: Column(
              children: [
                Text(day, style: TextStyle(color: isSelected ? accent : Colors.white24, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                AnimatedContainer(duration: const Duration(milliseconds: 250), height: 3, width: isSelected ? 28 : 0, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineContent(Color accent) {
    DateTime now = DateTime.now();
    List<String> days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    int todayIndex = now.weekday - 1;
    int selectedIndex = days.indexOf(selectedDay);

    DateTime displayDate = now.add(Duration(days: selectedIndex - todayIndex));
    String formattedDate = DateFormat('dd/MM/yyyy').format(displayDate);
    String dbFormatDate = DateFormat('yyyy-MM-dd').format(displayDate);

    List<dynamic> filteredBookings = allBookings.where((b) => b['booking_date'] == dbFormatDate).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(selectedDay, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 30),
        if (filteredBookings.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: Text("No bookings for this date", style: TextStyle(color: Colors.white24))))
        else
          ...filteredBookings.map((booking) => _buildTimelineItem(booking, accent)).toList(),
      ],
    );
  }

  Widget _buildTimelineItem(dynamic booking, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_safeTime(booking['start_time']), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
                const Text("to", style: TextStyle(color: Colors.white24, fontSize: 12)),
                Text(_safeTime(booking['end_time']), style: TextStyle(color: accent.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  CircleAvatar(radius: 14, backgroundColor: accent.withOpacity(0.15), child: Text("D", style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking['location'] ?? 'Studio', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text((booking['courses']?['course_name'] ?? 'CLASS').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(booking['instructor']?['instructor_name'] ?? 'TBA', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}