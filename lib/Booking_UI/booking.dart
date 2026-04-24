import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Payment_UI/payment.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final supabase = Supabase.instance.client;

  // 1. Date Logic (Existing)
  final List<String> _months = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
  final List<String> _days = List.generate(31, (index) => (index + 1).toString());

  String? _selectedMonth;
  String? _selectedDay;

  // 2. Time Logic (Existing)
  final List<String> _startTimes = [
    '10:00:00', '11:00:00', '12:00:00',
    '13:00:00', '14:00:00', '15:00:00', '16:00:00'
  ];

  String? _selectedStart;
  String _selectedEnd = "--:--:--"; // Changed default value for display consistency

  // 4. Location Logic (Existing)
  final List<String> _locations = ['Studio A', 'Studio B', 'Studio C'];
  String? _selectedLocation;

  // helper to calculate end time (Start + 1 hour) (Existing)
  void _updateEndTime(String start) {
    setState(() {
      _selectedStart = start;
      int hour = int.parse(start.split(':')[0]);
      // Ensures the hour is always 2 digits (e.g., 09:00:00 instead of 9:00:00)
      _selectedEnd = "${(hour + 1).toString().padLeft(2, '0')}:00:00";
    });
  }

  // 3. The Database function (Existing)
  Future<void> confirmBooking() async {
    try {
      String year = "2026";
      String formattedMonth = (_selectedMonth ?? '01').padLeft(2, '0');
      String formattedDay = (_selectedDay ?? '01').padLeft(2, '0');
      String finalDate = "$year-$formattedMonth-$formattedDay";

      final List<dynamic> response = await supabase.from('booking').insert({
        'course_id': 3,
        'booking_date': finalDate,
        'start_time': _selectedStart,
        'end_time': _selectedEnd, // <-- THIS VALUE NOW HAS A VISIBLE UI SYNC
        'booking_status': 'Confirmed',
        'location': _selectedLocation,
      }).select();

      if (response.isNotEmpty) {
        final newRow = response[0];
        int newId = newRow['booking_id'];

        // Display Formatting
        String formattedIdForDisplay = "B${newId.toString().padLeft(4, '0')}";

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Success! Booking ID: $formattedIdForDisplay saved.")),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Payment(bookingId: newId),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
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
            // --- DATE DROPDOWNS (Existing) ---
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

            // --- START TIME DROPDOWNS (Existing) ---
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

            const SizedBox(height: 25), // Spacing after Start Time

            // =========================================================================
            // --- ADDED: READ-ONLY END TIME DISPLAY ---
            // =========================================================================
            const Text("End Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            // Use a Container or stylized Card for read-only data
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _selectedEnd, // This value now correctly shows "Select Start First" or the actual end time
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 25), // Spacing after End Time
            // =========================================================================

            // --- LOCATION DROPDOWN (Existing) ---
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

            // --- CONFIRM BUTTON (Existing Logic with fixed validation) ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                // Fixed: The button disable logic was commented out in your snippet. Restored it.
                // Button remains disabled until full date, start time, AND location are chosen.
                onPressed: (_selectedStart == null ||
                    _selectedMonth == null ||
                    _selectedDay == null ||
                    _selectedLocation == null)
                    ? null
                    : confirmBooking,
                child: const Text("CONFIRM BOOKING", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}