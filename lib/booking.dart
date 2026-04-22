import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final supabase = Supabase.instance.client;

  // 1. Date Logic
  final List<String> _months = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
  final List<String> _days = List.generate(31, (index) => (index + 1).toString());

  String? _selectedMonth;
  String? _selectedDay;

  // 2. Time Logic
  final List<String> _startTimes = [
    '10:00:00', '11:00:00', '12:00:00',
    '13:00:00', '14:00:00', '15:00:00', '16:00:00'
  ];

  String? _selectedStart;
  String _selectedEnd = "Select Start First";

  // 4. Location Logic
  final List<String> _locations = ['Studio A', 'Studio B', 'Studio C']; // Add your real locations here
  String? _selectedLocation;

  // helper to calculate end time (Start + 1 hour)
  void _updateEndTime(String start) {
    setState(() {
      _selectedStart = start;
      int hour = int.parse(start.split(':')[0]);
      _selectedEnd = "${hour + 1}:00:00";
    });
  }

  // 3. The Database function
  Future<void> confirmBooking() async {
    try {
      // 1. Set your default year
      String year = "2026";

      // 2. Format the month and day (Adding fallback to '01' just in case)
      String formattedMonth = (_selectedMonth ?? '01').padLeft(2, '0');
      String formattedDay = (_selectedDay ?? '01').padLeft(2, '0');

      // 3. Create the separate Date string
      String finalDate = "$year-$formattedMonth-$formattedDay";

      final List<dynamic> response = await supabase.from('booking').insert({
        'course_id': 2,
        'booking_date': finalDate,
        'start_time': _selectedStart,
        'end_time': _selectedEnd,
        'booking_status': 'Confirmed',
        'location': _selectedLocation,
      }).select();

      // ID Formatting
      if (response.isNotEmpty) {
        final newRow = response[0];
        int newId = newRow['booking_id'];

        String formattedId = "B${newId.toString().padLeft(4, '0')}";

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Success! Booking ID: $formattedId saved.")),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- NEW: DATE DROPDOWNS ---
            const Text("Select Date (2026)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Month"),
                    items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (value) => setState(() => _selectedMonth = value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDay,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Day"),
                    items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (value) => setState(() => _selectedDay = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // --- TIME DROPDOWNS ---
            const Text("Start Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _selectedStart,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text("e.g 10:00:00"),
              items: _startTimes.map((time) {
                return DropdownMenuItem(value: time, child: Text(time));
              }).toList(),
              onChanged: (value) => _updateEndTime(value!),
            ),

            const SizedBox(height: 25),

            const Text("End Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(_selectedEnd, style: const TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 25),

            // --- NEW: LOCATION DROPDOWN ---
            const Text("Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _selectedLocation,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Select a studio"),
              items: _locations.map((loc) {
                return DropdownMenuItem(value: loc, child: Text(loc));
              }).toList(),
              onChanged: (value) => setState(() => _selectedLocation = value),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                // Disable button if date or time is not selected
                // Disable button if date, time, OR location is not selected
                onPressed: (_selectedStart == null ||
                    _selectedMonth == null ||
                    _selectedDay == null ||
                    _selectedLocation == null)
                    ? null
                    : confirmBooking,
                child: const Text("CONFIRM BOOKING", style: TextStyle(color: Colors.white)),
              ),
            ),

            const SizedBox(height: 25), // Spacing after End Time


          ],
        ),
      ),
    );
  }
}