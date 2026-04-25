import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Payment_UI/payment.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
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
      'address': 'No.33, Jalan Orkid 2, Taman Orkid, 28700 Bentong, Pahang',
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

  // --- FORM STATE ---
  final List<String> _months = List.generate(12, (i) => (i + 1).toString());
  final List<String> _startTimes = ['10:00:00', '11:00:00', '12:00:00', '13:00:00', '14:00:00', '15:00:00', '16:00:00'];

  // Notice _days is no longer 'final'. It needs to change based on the month!
  List<String> _days = List.generate(31, (i) => (i + 1).toString());

  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedStart;
  String _selectedEnd = "--:--:--";
  String? _selectedLocation;

  // --- LOGIC: DYNAMIC DATE VALIDATION ---
  void _onMonthChanged(String? newMonth) {
    if (newMonth == null) return;

    setState(() {
      _selectedMonth = newMonth;
      int monthNumber = int.parse(newMonth);
      int daysInMonth = 31;

      // Set limits for months with fewer than 31 days
      if (monthNumber == 2) {
        daysInMonth = 28; // 2026 is not a leap year
      } else if ([4, 6, 9, 11].contains(monthNumber)) {
        daysInMonth = 30;
      }

      // Update the day dropdown list
      _days = List.generate(daysInMonth, (i) => (i + 1).toString());

      // If the user previously selected day 31, but changed to Feb (which only has 28),
      // we must clear the selected day to prevent the app from crashing.
      if (_selectedDay != null && int.parse(_selectedDay!) > daysInMonth) {
        _selectedDay = null;
      }
    });
  }

  void _updateEndTime(String start) {
    setState(() {
      _selectedStart = start;
      int hour = int.parse(start.split(':')[0]);
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

  // --- LOGIC: PAST DATE VALIDATION & SUBMIT ---
  void _validateAndSubmit() {
    // 1. Convert their selection into a real Date and Time object
    int selectedHour = int.parse(_selectedStart!.split(':')[0]);
    DateTime selectedDateTime = DateTime(
        2026,
        int.parse(_selectedMonth!),
        int.parse(_selectedDay!),
        selectedHour
    );

    // 2. Check if the selected time is in the past
    if (selectedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You cannot book a date or time in the past!"),
          backgroundColor: Colors.red,
        ),
      );
      return; // Stop the code here
    }

    // 3. If everything is valid, submit to Supabase
    confirmBooking();
  }

  Future<void> confirmBooking() async {
    try {
      String finalDate = "2026-${_selectedMonth!.padLeft(2, '0')}-${_selectedDay!.padLeft(2, '0')}";
      final response = await supabase.from('booking').insert({
        'course_id': 4,
        'booking_date': finalDate,
        'start_time': _selectedStart,
        'end_time': _selectedEnd,
        'booking_status': 'Confirmed',
        'location': _selectedLocation,
      }).select();

      if (response.isNotEmpty && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => Payment(bookingId: response[0]['booking_id'])));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Booking")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Date (2026)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDropdown("Month", _selectedMonth, _months, _onMonthChanged)),
                const SizedBox(width: 10),
                Expanded(child: _buildDropdown("Day", _selectedDay, _days, (v) => setState(() => _selectedDay = v))),
              ],
            ),
            const SizedBox(height: 20),

            const Text("Select Time", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildDropdown("Start Time", _selectedStart, _startTimes, (v) => _updateEndTime(v!)),
            const SizedBox(height: 15),

            // End Time Display (Read Only)
            InputDecorator(
              decoration: const InputDecoration(labelText: "End Time", border: OutlineInputBorder()),
              child: Text(_selectedEnd, style: const TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 25),
            const Text("Studio Location", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                      "Manual Select",
                      _selectedLocation,
                      studioLocations.map((s) => s['name'] as String).toList(),
                          (v) => setState(() => _selectedLocation = v)
                  ),
                ),
                IconButton(icon: const Icon(Icons.my_location, color: Colors.purple), onPressed: _trackAndFindNearest),
                IconButton(icon: const Icon(Icons.map_outlined), onPressed: _openMapSelector),
              ],
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                // Notice how it points to _validateAndSubmit now instead of confirmBooking
                onPressed: (_selectedStart == null || _selectedMonth == null || _selectedDay == null || _selectedLocation == null)
                    ? null
                    : _validateAndSubmit,
                child: const Text("CONFIRM BOOKING", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(border: const OutlineInputBorder(), labelText: label),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }
}

// --- MAP PICKER SCREEN ---
class MapPickerScreen extends StatelessWidget {
  final List<Map<String, dynamic>> studios;
  const MapPickerScreen({super.key, required this.studios});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tap a Studio to Select")),
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
          infoWindow: InfoWindow(title: s['name'], snippet: s['address']),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Selected: ${s['name']}")));
            Navigator.pop(context, s['name']);
          },
        )).toSet(),
      ),
    );
  }
}