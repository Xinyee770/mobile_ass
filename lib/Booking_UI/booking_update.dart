import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BookingUpdate extends StatefulWidget {
  final dynamic booking;
  const BookingUpdate({super.key, required this.booking});

  @override
  State<BookingUpdate> createState() => _BookingUpdateState();
}

class _BookingUpdateState extends State<BookingUpdate> {
  final supabase = Supabase.instance.client;

  final List<Map<String, dynamic>> studioLocations = [
    {'name': 'Studio A', 'address': '38-06, Vista Danau Kota, Setapak, KL', 'lat': 3.2096, 'lng': 101.7188},
    {'name': 'Studio B', 'address': 'No.33 Taman Orkid, Bentong, Pahang', 'lat': 3.5222, 'lng': 101.9108},
    {'name': 'Studio C', 'address': 'Lingkaran SV2, Sunway Velocity, KL', 'lat': 3.1279, 'lng': 101.7247},
  ];

  DateTime _selectedDate = DateTime.now();
  String? _selectedStart;
  String? _selectedEnd;
  String? _selectedLocation;
  bool isCancelled = false;

  final List<String> _times = ['09:00:00', '10:00:00', '11:00:00', '13:00:00', '14:00:00', '15:00:00', '16:00:00', '17:00:00'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.booking['booking_date']);
    _selectedStart = widget.booking['start_time'];
    _selectedEnd = widget.booking['end_time'];

    String? dbLocation = widget.booking['location']?.toString();
    if (dbLocation != null) {
      final match = studioLocations.firstWhere((s) => s['name'] == dbLocation || dbLocation.contains(s['name']), orElse: () => {});
      if (match.isNotEmpty) _selectedLocation = match['name'];
    }

    // Check if the booking is already cancelled
    if (widget.booking['booking_status']?.toString().toLowerCase() == 'cancelled') {
      isCancelled = true;
    }
  }

  // --- LOGIC: CANCEL BOOKING (Sets status to Cancelled) ---
  Future<void> _handleCancelAction() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Cancel Booking", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to cancel this booking? You won't be able to edit it anymore.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("NO", style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("YES, CANCEL", style: TextStyle(color: Color(0xFFFF5959), fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('booking').update({'booking_status': 'Cancelled'}).eq('booking_id', widget.booking['booking_id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking Cancelled"), backgroundColor: Colors.orange));
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("Cancel Error: $e");
      }
    }
  }

  Future<void> _handleUpdate() async {
    try {
      await supabase.from('booking').update({
        'booking_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'start_time': _selectedStart,
        'end_time': _selectedEnd,
        'location': _selectedLocation,
      }).eq('booking_id', widget.booking['booking_id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);
    const dangerColor = Color(0xFFFF5959);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(
          title: Text(isCancelled ? "Booking Details" : "Edit Booking", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCancelled) _buildCancelledBanner(),

            _sectionLabel("1. CLASS INFORMATION"),
            _buildStaticCard(Icons.school_outlined, "Course", widget.booking['courses']?['course_name'] ?? "Class"),
            const SizedBox(height: 12),
            _buildStaticCard(Icons.person_outline, "Instructor", widget.booking['instructor']?['instructor_name'] ?? "Instructor"),

            const SizedBox(height: 32),
            _sectionLabel("2. STUDIO LOCATION"),
            _buildStudioRow(),

            const SizedBox(height: 32),
            _sectionLabel("3. SCHEDULE"),
            _buildActionTile(
                Icons.calendar_today,
                DateFormat('EEEE, d MMM yyyy').format(_selectedDate),
                onTap: isCancelled ? null : () async {
                  final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (d != null) setState(() => _selectedDate = d);
                }
            ),
            const SizedBox(height: 12),
            _buildActionTile(
                Icons.access_time,
                "$_selectedStart - $_selectedEnd",
                onTap: isCancelled ? null : _showTimePicker
            ),

            const SizedBox(height: 48),

            // --- BUTTONS ONLY SHOW IF NOT CANCELLED ---
            if (!isCancelled) ...[
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _handleUpdate,
                  child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: dangerColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _handleCancelAction,
                  child: const Text("CANCEL BOOKING", style: TextStyle(color: dangerColor, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Text(text, style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)));

  Widget _buildStaticCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A24), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: Colors.white24, size: 20),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ])
      ]),
    );
  }

  Widget _buildStudioRow() {
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLocation,
              disabledHint: Text(_selectedLocation ?? "", style: const TextStyle(color: Colors.white54)),
              dropdownColor: const Color(0xFF1E1E2C),
              isExpanded: true,
              items: studioLocations.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name'], style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: isCancelled ? null : (v) => setState(() => _selectedLocation = v),
            ),
          ),
        ),
      ),
      if (!isCancelled) ...[
        const SizedBox(width: 8),
        _iconBtn(Icons.my_location, () {}),
        const SizedBox(width: 8),
        _iconBtn(Icons.map_outlined, () {}),
      ]
    ]);
  }

  Widget _buildActionTile(IconData icon, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: isCancelled ? const Color(0xFF161620) : const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05))
        ),
        child: Row(children: [
          Icon(icon, color: isCancelled ? Colors.white24 : const Color(0xFF9D59FF), size: 20),
          const SizedBox(width: 16),
          Text(value, style: TextStyle(color: isCancelled ? Colors.white54 : Colors.white, fontSize: 15)),
          const Spacer(),
          if (!isCancelled) const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
      child: IconButton(icon: Icon(icon, color: const Color(0xFF9D59FF)), onPressed: onTap),
    );
  }

  void _showTimePicker() {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => ListView(
        shrinkWrap: true, padding: const EdgeInsets.all(20),
        children: _times.map((t) => ListTile(
          title: Text(t, style: const TextStyle(color: Colors.white)),
          onTap: () {
            setState(() {
              _selectedStart = t;
              _selectedEnd = "${(int.parse(t.split(':')[0]) + 1).toString().padLeft(2, '0')}:00:00";
            });
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  Widget _buildCancelledBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: const Color(0xFFFF5959).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFF5959).withOpacity(0.2))),
      child: const Row(children: [
        Icon(Icons.error_outline, color: Color(0xFFFF5959), size: 20),
        const SizedBox(width: 12),
        Text("This booking is cancelled and locked", style: TextStyle(color: Color(0xFFFF5959), fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}