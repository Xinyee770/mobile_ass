import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // --- STUDIO DATA ---
  final List<Map<String, dynamic>> studioLocations = [
    {
      'name': 'Studio A',
      'address': '38-06, Vista Danau Kota, Jalan Danau Saujana 1, Taman Danau Kota, 53300 Setapak, W.P. Kuala Lumpur',
      'lat': 3.2065,
      'lng': 101.7224
    },
    {
      'name': 'Studio B',
      'address': 'No.33 Jalan Orkid 2 Taman Orkid 28700 Bentong Pahang',
      'lat': 3.5222,
      'lng': 101.9000
    },
    {
      'name': 'Studio C',
      'address': 'Ground Floor, Bangunan Tan Sri Khaw Kai Boh (Block A), Jalan Genting Kelang, Setapak, 53300 Kuala Lumpur',
      'lat': 3.2145,
      'lng': 101.7265
    },
  ];

  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedStart;
  String? _selectedEnd;
  String? _selectedLocation;

  // NEW: Variable to track if the booking is cancelled
  bool isCancelled = false;

  final List<String> _months = List.generate(12, (i) => (i + 1).toString());
  final List<String> _days = List.generate(31, (i) => (i + 1).toString());
  final List<String> _times = ['10:00:00', '11:00:00', '12:00:00', '13:00:00', '14:00:00', '15:00:00', '16:00:00'];

  @override
  void initState() {
    super.initState();
    // Load existing booking data into the fields
    DateTime date = DateTime.parse(widget.booking['booking_date']);
    _selectedMonth = date.month.toString();
    _selectedDay = date.day.toString();
    _selectedStart = widget.booking['start_time'];
    _selectedEnd = widget.booking['end_time'];

    // Ensure the location from DB actually exists in our list to prevent Dropdown crash
    String dbLocation = widget.booking['location'];
    if (studioLocations.any((studio) => studio['name'] == dbLocation)) {
      _selectedLocation = dbLocation;
    }

    // CHECK IF CANCELLED
    String rawStatus = (widget.booking['booking_status'] ?? "").toString().toLowerCase();
    if (rawStatus == 'cancelled') {
      isCancelled = true;
    }
  }

  void _onStartTimeChanged(String newStart) {
    setState(() {
      _selectedStart = newStart;
      int hour = int.parse(newStart.split(':')[0]);
      _selectedEnd = "${(hour + 1).toString().padLeft(2, '0')}:00:00";
    });
  }

  // --- LOGIC: AUTO-TRACK LOCATION ---
  Future<void> _trackAndFindNearest() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location services disabled.")));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();

      double minDistance = double.infinity;
      String nearestStudio = "";

      for (var studio in studioLocations) {
        double distance = Geolocator.distanceBetween(
            position.latitude, position.longitude,
            studio['lat'], studio['lng']
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestStudio = studio['name'];
        }
      }

      setState(() => _selectedLocation = nearestStudio);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Nearest Studio found: $nearestStudio"))
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // --- LOGIC: OPEN MAP PICKER ---
  void _openMapSelector() async {
    final String? picked = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapPickerScreen(studios: studioLocations)),
    );
    if (picked != null) setState(() => _selectedLocation = picked);
  }

  // --- LOGIC: UPDATE BOOKING ---
  Future<void> _handleUpdate() async {
    try {
      String finalDate = "2026-${_selectedMonth!.padLeft(2, '0')}-${_selectedDay!.padLeft(2, '0')}";

      await supabase.from('booking').update({
        'booking_date': finalDate,
        'start_time': _selectedStart,
        'end_time': _selectedEnd,
        'location': _selectedLocation,
      }).eq('booking_id', widget.booking['booking_id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking successfully updated!")));
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  // --- LOGIC: CANCEL BOOKING ---
  Future<void> _cancelBooking() async {
    bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text("Cancel Booking", style: TextStyle(color: Colors.white)),
          content: const Text("Are you sure you want to cancel this booking? This action cannot be undone.", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("NO, KEEP IT", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("YES, CANCEL", style: TextStyle(color: Color(0xFFFF5959), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmCancel != true) return;

    try {
      await supabase.from('booking').update({
        'booking_status': 'Cancelled'
      }).eq('booking_id', widget.booking['booking_id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Booking has been cancelled."), backgroundColor: Color(0xFFFF5959))
        );
      }
    } catch (e) {
      debugPrint("Cancel Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(
          title: Text(isCancelled ? "View Booking" : "Update Booking", style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CANCELLED WARNING BANNER ---
            if (isCancelled)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5959).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF5959).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFFF5959)),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text("This booking is cancelled and can no longer be edited.",
                            style: TextStyle(color: Color(0xFFFF5959), fontSize: 13)
                        )
                    ),
                  ],
                ),
              ),

            Text(isCancelled ? "Booking Information" : "Edit Date & Studio", style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 25),

            Row(
              children: [
                Expanded(child: _buildDropdown("Month", _selectedMonth, _months, isCancelled ? null : (v) => setState(() => _selectedMonth = v))),
                const SizedBox(width: 15),
                Expanded(child: _buildDropdown("Day", _selectedDay, _days, isCancelled ? null : (v) => setState(() => _selectedDay = v))),
              ],
            ),
            const SizedBox(height: 20),

            _buildDropdown("Start Time", _selectedStart, _times, isCancelled ? null : (v) => _onStartTimeChanged(v!)),

            const SizedBox(height: 20),

            InputDecorator(
              decoration: InputDecoration(
                labelText: "End Time",
                labelStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white10),
                    borderRadius: BorderRadius.circular(12)
                ),
                disabledBorder: OutlineInputBorder( // Keep it looking nice even when disabled
                    borderSide: const BorderSide(color: Colors.white10),
                    borderRadius: BorderRadius.circular(12)
                ),
                focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF9D59FF)),
                    borderRadius: BorderRadius.circular(12)
                ),
              ),
              child: Text(
                  _selectedEnd ?? "--:--:--",
                  style: TextStyle(color: isCancelled ? Colors.white54 : Colors.white, fontSize: 16)
              ),
            ),

            const SizedBox(height: 20),

            // --- LOCATION ROW WITH MAP BUTTONS ---
            const Text("Location", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                      "Select Location",
                      _selectedLocation,
                      studioLocations.map((s) => s['name'] as String).toList(),
                      isCancelled ? null : (v) => setState(() => _selectedLocation = v)
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.my_location, color: isCancelled ? Colors.white38 : const Color(0xFF9D59FF)),
                  onPressed: isCancelled ? null : _trackAndFindNearest,
                ),
                IconButton(
                  icon: Icon(Icons.map_outlined, color: isCancelled ? Colors.white38 : Colors.white70),
                  onPressed: isCancelled ? null : _openMapSelector,
                ),
              ],
            ),

            const Spacer(),

            // --- ONLY SHOW BUTTONS IF NOT CANCELLED ---
            if (!isCancelled) ...[
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D59FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: _handleUpdate,
                  child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity, height: 55,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF5959), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: _cancelBooking,
                  child: const Text("CANCEL BOOKING", style: TextStyle(color: Color(0xFFFF5959), fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // Notice how onChanged can now accept 'null' to disable the dropdown
  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?>? onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1E1E2C),
      style: TextStyle(color: onChanged == null ? Colors.white54 : Colors.white), // Dims text if disabled
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white10),
            borderRadius: BorderRadius.circular(12)
        ),
        disabledBorder: OutlineInputBorder( // Adds border for disabled state so it doesn't look weird
            borderSide: const BorderSide(color: Colors.white10),
            borderRadius: BorderRadius.circular(12)
        ),
        focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF9D59FF)),
            borderRadius: BorderRadius.circular(12)
        ),
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }
}

// --- MAP PICKER SCREEN (Unchanged) ---
class MapPickerScreen extends StatelessWidget {
  final List<Map<String, dynamic>> studios;
  const MapPickerScreen({super.key, required this.studios});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tap a Studio to Select", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F16),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GoogleMap(
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        initialCameraPosition: const CameraPosition(
            target: LatLng(3.2145, 101.7265),
            zoom: 11
        ),
        markers: studios.map((s) => Marker(
          markerId: MarkerId(s['name']),
          position: LatLng(s['lat'], s['lng']),
          infoWindow: InfoWindow(
            title: s['name'],
            snippet: s['address'],
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Selected: ${s['name']}")),
            );
            Navigator.pop(context, s['name']);
          },
        )).toSet(),
      ),
    );
  }
}