import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
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

  // --- Studio Data ---
  final List<Map<String, dynamic>> studios = [
    {
      'id': 'A',
      'name': 'Studio A (Setapak)',
      'address': '38-06, Vista Danau Kota, KL',
      'lat': 3.2096, 'lng': 101.7188
    },
    {
      'id': 'B',
      'name': 'Studio B (Bentong)',
      'address': 'No.33 Taman Orkid, Bentong',
      'lat': 3.5222, 'lng': 101.9108
    },
    {
      'id': 'C',
      'name': 'Studio C (KL)',
      'address': 'Sunway Velocity, KL',
      'lat': 3.1279, 'lng': 101.7247
    },
  ];

  // Static Time Slots
  final List<String> _allTimeSlots = [
    '09:00:00', '10:00:00', '11:00:00', '13:00:00',
    '14:00:00', '15:00:00', '16:00:00', '17:00:00'
  ];

  // State Data
  List<Map<String, dynamic>> coursesWithInstructors = [];
  List<Map<String, dynamic>> displayedInstructors = [];
  List<String> busySlots = [];

  // Selections
  dynamic selectedCourseId;
  dynamic selectedInstructorId;
  String? selectedStudioId;
  DateTime selectedDate = DateTime.now();
  String? _selectedTime;

  bool isLoading = true;
  bool isCheckingSlots = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 1. Load Data
  Future<void> _loadData() async {
    try {
      final data = await supabase.from('courses').select('*, instructor(*)');
      final filteredData = (data as List).where((course) {
        final inst = course['instructor'];
        return inst != null && inst['is_private'] == true;
      }).toList();

      setState(() {
        coursesWithInstructors = List<Map<String, dynamic>>.from(filteredData);
        isLoading = false;
      });
    } catch (e) {
      _showSnackBar("Load failed: $e", Colors.red);
      setState(() => isLoading = false);
    }
  }

  // 2. Nearest Studio Logic
  Future<void> _selectNearestStudio() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();

      Position position = await Geolocator.getCurrentPosition();
      double shortestDistance = double.infinity;
      String? closestId;

      for (var studio in studios) {
        double dist = Geolocator.distanceBetween(position.latitude, position.longitude, studio['lat'], studio['lng']);
        if (dist < shortestDistance) {
          shortestDistance = dist;
          closestId = studio['id'];
        }
      }
      setState(() => selectedStudioId = closestId);
      _showSnackBar("Nearest studio detected", Colors.green);
    } catch (e) {
      _showSnackBar("Location detection failed", Colors.red);
    }
  }

  // 3. Fetch Busy Slots
  Future<void> _fetchBusySlots() async {
    if (selectedInstructorId == null) return;
    setState(() {
      isCheckingSlots = true;
      _selectedTime = null; // Reset selection when date/instructor changes
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    try {
      final bookingData = await supabase.from('booking').select('start_time').eq('instructor_id', selectedInstructorId).eq('booking_date', dateStr);
      final courseData = await supabase.from('courses').select('schedule').eq('instructor_id', selectedInstructorId);

      setState(() {
        final privateBusy = (bookingData as List).map((e) => e['start_time'].toString());
        final publicBusy = (courseData as List).map((e) => e['schedule'].toString());
        busySlots = {...privateBusy, ...publicBusy}.toList();
        isCheckingSlots = false;
      });
    } catch (e) {
      setState(() => isCheckingSlots = false);
    }
  }

  // --- NEW: Confirmation Dialog Logic ---
  Future<void> _showConfirmationDialog() async {
    // 1. Gather all names for the UI display
    final courseName = coursesWithInstructors.firstWhere((c) => c['course_id'] == selectedCourseId)['course_name'];
    final instructorName = displayedInstructors.firstWhere((i) => i['instructor_id'] == selectedInstructorId)['instructor_name'];
    final studioName = studios.firstWhere((s) => s['id'] == selectedStudioId)['name'];
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(selectedDate);
    final timeStr = _selectedTime!.substring(0, 5); // Format HH:mm

    // 2. Show the Dialog
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF9D59FF)),
            SizedBox(width: 10),
            Text("Confirm Booking", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Please review your details:", style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            // Removed the manual spaces and colons from here:
            _buildDialogDetailRow(Icons.auto_awesome, "Course", courseName),
            _buildDialogDetailRow(Icons.person, "Instructor", instructorName),
            _buildDialogDetailRow(Icons.location_on, "Studio", studioName),
            _buildDialogDetailRow(Icons.calendar_today, "Date", dateStr),
            _buildDialogDetailRow(Icons.access_time, "Time", "$timeStr - ${int.parse(timeStr.split(':')[0]) + 1}:00"),
          ],
        ),
        actions: [
          // Wrapping the buttons in a Row allows us to control their widths perfectly
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    alignment: Alignment.center, // Ensures the text stays in the exact middle
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "NO",
                    style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 8), // Small gap between the buttons
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D59FF), // Your brand purple
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                  ),
                  onPressed: () {
                    Navigator.pop(context, true);
                    // Add your booking logic here if it's not already handled
                  },
                  child: const Text(
                    "YES",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );

    // 3. If user clicked YES, proceed with the actual booking
    if (confirm == true) {
      _submitBooking();
    }
  }

  // Helper widget with fixed alignment
  Widget _buildDialogDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          // Set a fixed width for the label so the colons always align perfectly
          SizedBox(
            width: 85,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          const Text(" :  ", style: TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 4. Submit Booking
  Future<void> _submitBooking() async {
    try {
      final DateFormat df = DateFormat("HH:mm:ss");
      String endTime = df.format(df.parse(_selectedTime!).add(const Duration(hours: 1)));
      final String studioName = studios.firstWhere((s) => s['id'] == selectedStudioId)['name'];

      final response = await supabase.from('booking').insert({
        'user_id': 1, // Replace with actual logged in user ID
        'course_id': selectedCourseId,
        'instructor_id': selectedInstructorId,
        'booking_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'start_time': _selectedTime,
        'end_time': endTime,
        'location': studioName,
        'booking_status': 'Confirmed',
      }).select();

      if (response != null && (response as List).isNotEmpty) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Payment(bookingId: response[0]['booking_id'])),
        ).then((_) => _fetchBusySlots());
      }
    } catch (e) {
      _showSnackBar("Booking failed", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(
        title: const Text("Private Lesson", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator(color: accentColor)) : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("1. Choose Course"),
            _buildCourseDropdown(),
            const SizedBox(height: 24),

            _sectionTitle("2. Select Studio"),
            _buildStudioLocationRow(),
            const SizedBox(height: 24),

            _sectionTitle("3. Assigned Instructor"),
            _buildInstructorDropdown(),
            const SizedBox(height: 24),

            _sectionTitle("4. Select Date"),
            _buildDateButton(),
            const SizedBox(height: 32),

            _sectionTitle("5. Available Times"),
            _buildTimeWrap(),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    disabledBackgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                // --- CHANGED to trigger the dialog ---
                onPressed: (_selectedTime == null || selectedStudioId == null) ? null : _showConfirmationDialog,
                child: const Text("BOOK NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildTimeWrap() {
    if (selectedInstructorId == null) {
      return const Text("Select an instructor first", style: TextStyle(color: Colors.white24));
    }
    if (isCheckingSlots) return const Center(child: CircularProgressIndicator());

    final DateTime now = DateTime.now();
    final bool isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    return Wrap(
      spacing: 12, runSpacing: 12,
      children: _allTimeSlots.map((time) {
        int slotHour = int.parse(time.split(':')[0]);

        // VALIDATION: Past hours today OR already booked
        bool isPast = isToday && slotHour <= now.hour;
        bool isBusy = busySlots.contains(time);
        bool isDisabled = isPast || isBusy;
        bool isSelected = _selectedTime == time;

        return ChoiceChip(
          label: Text(time.substring(0, 5), style: TextStyle(color: isSelected ? Colors.white : (isDisabled ? Colors.white12 : Colors.white70))),
          selected: isSelected,
          selectedColor: const Color(0xFF9D59FF),
          backgroundColor: const Color(0xFF1E1E2C),
          disabledColor: Colors.black26,
          onSelected: isDisabled ? null : (val) => setState(() => _selectedTime = time),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? const Color(0xFF9D59FF) : Colors.white10)),
        );
      }).toList(),
    );
  }

  Widget _buildStudioLocationRow() {
    return Row(children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          value: selectedStudioId,
          hint: const Text("Select Studio", style: TextStyle(color: Colors.white30)),
          dropdownColor: const Color(0xFF1E1E2C),
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(),
          items: studios.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))).toList(),
          onChanged: (val) => setState(() => selectedStudioId = val),
        ),
      ),
      const SizedBox(width: 8),
      _iconButton(Icons.my_location, _selectNearestStudio),
      const SizedBox(width: 8),
      _iconButton(Icons.map_outlined, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StudioMapScreen(studios: studios, onStudioSelected: (id) => setState(() => selectedStudioId = id))));
      }),
    ]);
  }

  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<dynamic>(
      value: selectedCourseId,
      dropdownColor: const Color(0xFF1E1E2C),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(),
      items: coursesWithInstructors.map((c) => DropdownMenuItem(value: c['course_id'], child: Text(c['course_name']))).toList(),
      onChanged: (val) {
        setState(() {
          selectedCourseId = val;
          selectedInstructorId = null;
          final selectedCourse = coursesWithInstructors.firstWhere((c) => c['course_id'] == val);
          displayedInstructors = selectedCourse['instructor'] != null ? [selectedCourse['instructor']] : [];
        });
      },
    );
  }

  Widget _buildInstructorDropdown() {
    return DropdownButtonFormField<dynamic>(
      value: selectedInstructorId,
      hint: const Text("Instructor", style: TextStyle(color: Colors.white30)),
      dropdownColor: const Color(0xFF1E1E2C),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(),
      items: displayedInstructors.map((inst) => DropdownMenuItem(value: inst['instructor_id'], child: Text(inst['instructor_name']))).toList(),
      onChanged: (val) {
        setState(() => selectedInstructorId = val);
        _fetchBusySlots();
      },
    );
  }

  Widget _buildDateButton() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
        if (picked != null) {
          setState(() => selectedDate = picked);
          _fetchBusySlots();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(DateFormat('EEEE, d MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.white)),
          const Icon(Icons.calendar_today, color: Color(0xFF9D59FF), size: 20),
        ]),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) => Container(decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)), child: IconButton(icon: Icon(icon, color: const Color(0xFF9D59FF)), onPressed: onTap));
  Widget _sectionTitle(String text) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)));
  InputDecoration _inputDecoration() => InputDecoration(filled: true, fillColor: const Color(0xFF1E1E2C), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF9D59FF))));
  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}

// --- MAP SCREEN ---
class StudioMapScreen extends StatelessWidget {
  final List<Map<String, dynamic>> studios;
  final Function(String) onStudioSelected;
  const StudioMapScreen({super.key, required this.studios, required this.onStudioSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Studio Locations"), backgroundColor: Colors.black),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(studios[0]['lat'], studios[0]['lng']), zoom: 10),
        markers: studios.map((s) => Marker(markerId: MarkerId(s['id']), position: LatLng(s['lat'], s['lng']), infoWindow: InfoWindow(title: s['name'], onTap: () { onStudioSelected(s['id']); Navigator.pop(context); }))).toSet(),
      ),
    );
  }
}