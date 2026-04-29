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
  bool _isLoading = false;

  final List<Map<String, dynamic>> studioLocations = [
    {'name': 'Studio A', 'address': '38-06, Vista Danau Kota, Setapak, KL', 'lat': 3.2096, 'lng': 101.7188},
    {'name': 'Studio B', 'address': 'No.33 Taman Orkid, Bentong, Pahang', 'lat': 3.5222, 'lng': 101.9108},
    {'name': 'Studio C', 'address': 'Lingkaran SV2, Sunway Velocity, KL', 'lat': 3.1279, 'lng': 101.7247},
  ];

  late DateTime _selectedDate;
  String? _selectedStart;
  String? _selectedEnd;
  String? _selectedLocation;

  bool isCancelled = false;
  bool isAttended = false;
  bool isMissed = false;

  final List<String> _times = [
    '09:00:00', '10:00:00', '11:00:00',
    '13:00:00', '14:00:00', '15:00:00',
    '16:00:00', '17:00:00'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.booking['booking_date']);
    _selectedStart = widget.booking['start_time'];
    _selectedEnd = widget.booking['end_time'];

    String? dbLocation = widget.booking['location']?.toString();
    if (dbLocation != null) {
      final match = studioLocations.firstWhere(
              (s) => s['name'] == dbLocation || dbLocation.contains(s['name']),
          orElse: () => {}
      );
      if (match.isNotEmpty) _selectedLocation = match['name'];
    }

    final status = widget.booking['booking_status']?.toString().toLowerCase() ?? '';
    if (status == 'cancelled') {
      isCancelled = true;
    } else if (status == 'attended' || status == 'completed') {
      isAttended = true;
    } else if (status == 'missed') { // Check for missed status
      isMissed = true;
    }
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return "-";
    return time.substring(0, 5);
  }

  // --- LOCATION LOGIC ---

  Future<void> _selectNearestStudio() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Detecting your location..."), backgroundColor: Colors.blue),
      );

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please turn on your phone's GPS."), backgroundColor: Colors.orange),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permission denied."), backgroundColor: Colors.red),
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));

      double shortestDistance = double.infinity;
      String? closestName;

      for (var studio in studioLocations) {
        double dist = Geolocator.distanceBetween(
            position.latitude, position.longitude, studio['lat'], studio['lng']);
        if (dist < shortestDistance) {
          shortestDistance = dist;
          closestName = studio['name'];
        }
      }

      setState(() => _selectedLocation = closestName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nearest studio selected!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // --- DATABASE LOGIC ---

  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw "User not authenticated";

      final bookingId = widget.booking['booking_id'];

      final response = await supabase
          .from('booking')
          .update({
        'booking_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'start_time': _selectedStart,
        'end_time': _selectedEnd,
        'location': _selectedLocation,
      })
          .eq('booking_id', bookingId)
          .eq('user_id', userId)
          .select();

      if (response.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Booking updated successfully!"), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw "No rows were updated. Check your permissions.";
      }
    } catch (e) {
      debugPrint("Update Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCancelAction() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Cancel Booking", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure? This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("NO", style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("YES, CANCEL", style: TextStyle(color: Color(0xFFFF5959), fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase
            .from('booking')
            .update({'booking_status': 'Cancelled'})
            .eq('booking_id', widget.booking['booking_id']);

        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        debugPrint("Cancel Error: $e");
      }
    }
  }

  // --- POPUPS ---

  Future<void> _showSaveChangesConfirmation() async {
    final oldDateStr = DateFormat('EEEE, d MMM yyyy').format(DateTime.parse(widget.booking['booking_date']));
    final newDateStr = DateFormat('EEEE, d MMM yyyy').format(_selectedDate);
    final oldTime = "${_formatTime(widget.booking['start_time'])} - ${_formatTime(_selectedEnd)}";
    final newTime = "${_formatTime(_selectedStart)} - ${_formatTime(_selectedEnd)}";

    final String oldLoc = widget.booking['location'] ?? "Unknown";
    final String newLoc = _selectedLocation ?? "Unknown";

    final bool hasChanges = (oldDateStr != newDateStr) || (oldTime != newTime) || (oldLoc != newLoc);

    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No changes detected."), backgroundColor: Colors.white24),
      );
      return;
    }

    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Review Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (oldLoc != newLoc) _buildChangeRow("Location", oldLoc, newLoc),
            if (oldDateStr != newDateStr) _buildChangeRow("Date", oldDateStr, newDateStr),
            if (oldTime != newTime) _buildChangeRow("Time", oldTime, newTime),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("BACK", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9D59FF)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("CONFIRM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) _handleUpdate();
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);
    const dangerColor = Color(0xFFFF5959);
    const successColor = Color(0xFF00C853);
    const warningColor = Color(0xFFFFB300); // Added for missed status

    final bool isLocked = isCancelled || isAttended || isMissed;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(
          title: Text(isLocked ? "Booking Details" : "Edit Booking", style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banners
            if (isCancelled) _buildStatusBanner(dangerColor, "This booking is cancelled and locked", Icons.error_outline),
            if (isAttended) _buildStatusBanner(successColor, "You have attended this class", Icons.check_circle_outline),
            if (isMissed) _buildStatusBanner(warningColor, "You missed this class", Icons.info_outline),

            _sectionLabel("1. CLASS INFORMATION"),
            _buildStaticCard(Icons.school_outlined, "Course", widget.booking['courses']?['course_name'] ?? "Class"),
            const SizedBox(height: 12),
            _buildStaticCard(Icons.person_outline, "Instructor", widget.booking['instructor']?['instructor_name'] ?? "Instructor"),

            const SizedBox(height: 32),
            _sectionLabel("2. STUDIO LOCATION"),
            _buildStudioRow(isLocked),

            const SizedBox(height: 32),
            _sectionLabel("3. SCHEDULE"),
            _buildActionTile(
                Icons.calendar_today,
                DateFormat('EEEE, d MMM yyyy').format(_selectedDate),
                isLocked,
                onTap: isLocked ? null : () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
                  );
                  if (d != null) setState(() => _selectedDate = d);
                }
            ),
            const SizedBox(height: 12),
            _buildActionTile(
                Icons.access_time,
                "${_formatTime(_selectedStart)} - ${_formatTime(_selectedEnd)}",
                isLocked,
                onTap: isLocked ? null : _showTimePicker
            ),

            const SizedBox(height: 48),

            if (!isLocked) ...[
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _showSaveChangesConfirmation,
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

            // Show lock message if locked
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

  Widget _buildChangeRow(String label, String oldVal, String newVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(oldVal, style: const TextStyle(color: Colors.white38, decoration: TextDecoration.lineThrough, fontSize: 12))),
              const Icon(Icons.arrow_forward, color: Color(0xFF9D59FF), size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(newVal, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ],
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

  Widget _buildStudioRow(bool isLocked) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: isLocked ? const Color(0xFF161620) : const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLocation,
                disabledHint: Text(_selectedLocation ?? "Select Location", style: const TextStyle(color: Colors.white54)),
                dropdownColor: const Color(0xFF1E1E2C),
                isExpanded: true,
                items: studioLocations.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name'], style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: isLocked ? null : (v) => setState(() => _selectedLocation = v),
              ),
            ),
          ),
        ),

        if (!isLocked) ...[
          const SizedBox(width: 8),
          _iconButton(Icons.my_location, _selectNearestStudio),
          const SizedBox(width: 8),
          _iconButton(Icons.map_outlined, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => StudioMapScreen(
                  studios: studioLocations,
                  onStudioSelected: (name) => setState(() => _selectedLocation = name),
                ),
              ),
            );
          }),
        ]
      ],
    );
  }

  Widget _iconButton(IconData i, Function() onTap) {
    return Container(
        decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
        child: IconButton(icon: Icon(i, color: const Color(0xFF9D59FF)), onPressed: onTap)
    );
  }

  Widget _buildActionTile(IconData icon, String value, bool isLocked, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: isLocked ? const Color(0xFF161620) : const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05))
        ),
        child: Row(children: [
          Icon(icon, color: isLocked ? Colors.white24 : const Color(0xFF9D59FF), size: 20),
          const SizedBox(width: 16),
          Text(value, style: TextStyle(color: isLocked ? Colors.white54 : Colors.white, fontSize: 15)),
          const Spacer(),
          if (!isLocked) const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }

  void _showTimePicker() {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => ListView(
        shrinkWrap: true, padding: const EdgeInsets.all(20),
        children: _times.map((t) => ListTile(
          title: Text(_formatTime(t), style: const TextStyle(color: Colors.white)),
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

  Widget _buildStatusBanner(Color color, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}

class StudioMapScreen extends StatelessWidget {
  final List<Map<String, dynamic>> studios;
  final Function(String) onStudioSelected;

  const StudioMapScreen({super.key, required this.studios, required this.onStudioSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Studio Locations", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: GoogleMap(
        myLocationEnabled: true,
        initialCameraPosition: CameraPosition(target: LatLng(studios[0]['lat'], studios[0]['lng']), zoom: 10),
        markers: studios.map((s) => Marker(
          markerId: MarkerId(s['name']),
          position: LatLng(s['lat'], s['lng']),
          infoWindow: InfoWindow(
              title: s['name'],
              snippet: s['address'],
              onTap: () {
                onStudioSelected(s['name']);
                Navigator.pop(context);
              }
          ),
        )).toSet(),
      ),
    );
  }
}