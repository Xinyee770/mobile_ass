import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PublicUpdate extends StatefulWidget {
  final dynamic booking;
  const PublicUpdate({super.key, required this.booking});

  @override
  State<PublicUpdate> createState() => _PublicUpdateState();
}

class _PublicUpdateState extends State<PublicUpdate> {
  final supabase = Supabase.instance.client;

  bool isCancelled = false;
  bool isAttended = false;
  bool isMissed = false;

  @override
  void initState() {
    super.initState();

    final status = widget.booking['booking_status']?.toString().toLowerCase() ?? '';

    if (status == 'cancelled') {
      isCancelled = true;
    } else if (status == 'attended' || status == 'completed') {
      isAttended = true;
    } else if (status == 'missed') {
      isMissed = true;
    }
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return "-";
    try {
      return time.substring(0, 5);
    } catch (e) {
      return time;
    }
  }

  // --- LOGIC: CANCEL PUBLIC BOOKING ---
  Future<void> _handleCancelPublic() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cancel Class", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to cancel your spot? This cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("NO", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("YES, CANCEL", style: TextStyle(color: Color(0xFFFF5959), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final user = supabase.auth.currentUser;
        if (user == null) return;

        await supabase
            .from('booking')
            .update({'booking_status': 'Cancelled'})
            .eq('booking_id', widget.booking['booking_id'])
            .eq('user_id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Booking Cancelled"), backgroundColor: Colors.orange),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("Cancel Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0F0F16);
    const accentColor = Color(0xFF9D59FF);
    const dangerColor = Color(0xFFFF5959);
    const successColor = Color(0xFF00C853);
    const warningColor = Color(0xFFFFB300);

    final bool isLocked = isCancelled || isAttended || isMissed;

    DateTime date = DateTime.parse(widget.booking['booking_date']);
    String formattedDate = DateFormat('EEEE, d MMMM yyyy').format(date);

    String startTime = _formatTime(widget.booking['start_time']);
    String endTime = _formatTime(widget.booking['end_time']);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(isLocked ? "Booking Detail" : "Manage Booking",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCancelled) _buildStatusBanner(dangerColor, "Booking Cancelled", Icons.cancel_outlined),
            if (isAttended) _buildStatusBanner(successColor, "Class Attended", Icons.check_circle_outline),
            if (isMissed) _buildStatusBanner(warningColor, "Class Missed", Icons.info_outline),

            _sectionLabel("COURSE INFORMATION"),
            _buildDetailTile(Icons.auto_awesome, "Class Name", widget.booking['courses']?['course_name'] ?? "Public Class", accentColor),
            const SizedBox(height: 12),
            _buildDetailTile(Icons.person_outline, "Instructor", widget.booking['instructor']?['instructor_name'] ?? "Studio Instructor", accentColor),

            const SizedBox(height: 32),

            _sectionLabel("LOCATION"),
            _buildDetailTile(Icons.location_on_outlined, "Studio Location", widget.booking['location'] ?? "Main Studio", accentColor),

            const SizedBox(height: 32),

            _sectionLabel("TIME & SCHEDULE"),
            _buildDetailTile(Icons.calendar_today_outlined, "Date", formattedDate, accentColor),
            const SizedBox(height: 12),
            _buildDetailTile(Icons.access_time, "Time Slot", "$startTime - $endTime", accentColor),

            const SizedBox(height: 60),

            if (!isLocked)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: dangerColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _handleCancelPublic,
                  child: const Text("CANCEL BOOKING", style: TextStyle(color: dangerColor, fontWeight: FontWeight.bold)),
                ),
              ),

            if (isLocked)
              const Center(
                child: Text(
                  "This record is locked and kept for your history.",
                  style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              )
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(text, style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
  );

  Widget _buildDetailTile(IconData icon, String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(Color color, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
