import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingUpdate extends StatefulWidget {
  final dynamic booking;
  const BookingUpdate({super.key, required this.booking});

  @override
  State<BookingUpdate> createState() => _BookingUpdateState();
}

class _BookingUpdateState extends State<BookingUpdate> {
  final supabase = Supabase.instance.client;

  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedStart;
  String? _selectedEnd;
  String? _selectedLocation;

  final List<String> _months = List.generate(12, (i) => (i + 1).toString());
  final List<String> _days = List.generate(31, (i) => (i + 1).toString());
  final List<String> _times = ['10:00:00', '11:00:00', '12:00:00', '13:00:00', '14:00:00', '15:00:00', '16:00:00'];
  final List<String> _locations = ['Studio A', 'Studio B', 'Studio C'];

  @override
  void initState() {
    super.initState();
    DateTime date = DateTime.parse(widget.booking['booking_date']);
    _selectedMonth = date.month.toString();
    _selectedDay = date.day.toString();
    _selectedStart = widget.booking['start_time'];
    _selectedEnd = widget.booking['end_time'];
    _selectedLocation = widget.booking['location'];
  }

  void _onStartTimeChanged(String newStart) {
    setState(() {
      _selectedStart = newStart;
      int hour = int.parse(newStart.split(':')[0]);
      _selectedEnd = "${(hour + 1).toString().padLeft(2, '0')}:00:00"; // Automatically sets end time
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(
          title: const Text("Update Booking", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Edit Date & Studio", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(child: _buildDropdown("Month", _selectedMonth, _months, (v) => setState(() => _selectedMonth = v))),
                const SizedBox(width: 15),
                Expanded(child: _buildDropdown("Day", _selectedDay, _days, (v) => setState(() => _selectedDay = v))),
              ],
            ),
            const SizedBox(height: 20),

            // Start Time Selection
            _buildDropdown("Start Time", _selectedStart, _times, (v) => _onStartTimeChanged(v!)),

            const SizedBox(height: 20),

            // --- END TIME COLUMN (NOW FOLLOWS START TIME STYLE) ---
            InputDecorator(
              decoration: InputDecoration(
                labelText: "End Time",
                labelStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white10),
                    borderRadius: BorderRadius.circular(12)
                ),
                // Uses the same border style as the dropdowns
                focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF9D59FF)),
                    borderRadius: BorderRadius.circular(12)
                ),
              ),
              child: Text(
                  _selectedEnd ?? "--:--:--",
                  style: const TextStyle(color: Colors.white, fontSize: 16)
              ),
            ),

            const SizedBox(height: 20),
            _buildDropdown("Location", _selectedLocation, _locations, (v) => setState(() => _selectedLocation = v)),

            const Spacer(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1E1E2C),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
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