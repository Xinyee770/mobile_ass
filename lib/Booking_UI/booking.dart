import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final supabase = Supabase.instance.client;

  // --- Updated Studio Data with your specific addresses and coordinates ---
  final List<Map<String, dynamic>> studios = [
    {
      'id': 'A',
      'name': 'Studio A (Setapak)',
      'address': '38-06, Vista Danau Kota, Jalan Danau Saujana 1, 53300 KL',
      'lat': 3.2096, 'lng': 101.7188
    },
    {
      'id': 'B',
      'name': 'Studio B (Bentong)',
      'address': 'No.33 Taman Orkid, 28700 Bentong, Pahang',
      'lat': 3.5222, 'lng': 101.9108
    },
    {
      'id': 'C',
      'name': 'Studio C (KL)',
      'address': 'Lingkaran SV2, 55100 Kuala Lumpur',
      'lat': 3.1279, 'lng': 101.7247
    },
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

  final List<String> _allTimeSlots = [
    '09:00:00', '10:00:00', '11:00:00', '13:00:00',
    '14:00:00', '15:00:00', '16:00:00', '17:00:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 1. Load Private Courses
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

  // 2. Logic: Selection & Nearest Studio GPS
  void _onCourseSelected(dynamic courseId) {
    setState(() {
      selectedCourseId = courseId;
      selectedInstructorId = null;
      busySlots = [];
      _selectedTime = null;
      final selectedCourse = coursesWithInstructors.firstWhere((c) => c['course_id'] == courseId);
      displayedInstructors = selectedCourse['instructor'] != null ? [selectedCourse['instructor']] : [];
    });
  }

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
      _showSnackBar("Nearest studio detected: Studio $closestId", Colors.green);
    } catch (e) {
      _showSnackBar("Location detection failed", Colors.red);
    }
  }

  // 3. Availability Check
  Future<void> _fetchBusySlots() async {
    if (selectedInstructorId == null) return;
    setState(() => isCheckingSlots = true);
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

  // 4. Submit Booking
  Future<void> _submitBooking() async {
    if (_selectedTime == null || selectedStudioId == null) {
      _showSnackBar("Please select a studio and time", Colors.orange);
      return;
    }

    try {
      final DateFormat df = DateFormat("HH:mm:ss");
      String endTime = df.format(df.parse(_selectedTime!).add(const Duration(hours: 1)));
      final String studioName = studios.firstWhere((s) => s['id'] == selectedStudioId)['name'];

      await supabase.from('booking').insert({
        'user_id': 1,
        'course_id': selectedCourseId,
        'instructor_id': selectedInstructorId,
        'booking_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'start_time': _selectedTime,
        'end_time': endTime,
        'location': studioName,
        'booking_status': 'Confirmed',
      });

      _showSnackBar("Booking successful!", Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(
        title: const Text("Private Lesson", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
            isCheckingSlots ? const Center(child: CircularProgressIndicator(color: accentColor)) : _buildTimeWrap(),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: (_selectedTime == null || selectedStudioId == null) ? null : _submitBooking,
                child: const Text("BOOK NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioLocationRow() {
    return Row(
      children: [
        Expanded(
          flex: 3,
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
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
      child: IconButton(icon: Icon(icon, color: const Color(0xFF9D59FF)), onPressed: onTap),
    );
  }

  // --- UI Helpers ---
  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<dynamic>(
      value: selectedCourseId,
      dropdownColor: const Color(0xFF1E1E2C),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(),
      items: coursesWithInstructors.map((c) => DropdownMenuItem(value: c['course_id'], child: Text(c['course_name']))).toList(),
      onChanged: (val) => _onCourseSelected(val),
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
          if (selectedInstructorId != null) _fetchBusySlots();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('EEEE, d MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.white)),
            const Icon(Icons.calendar_today, color: Color(0xFF9D59FF), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeWrap() {
    return Wrap(
      spacing: 12, runSpacing: 12,
      children: _allTimeSlots.map((time) {
        final bool isBusy = busySlots.contains(time);
        return ChoiceChip(
          label: Text(time.substring(0, 5)),
          selected: _selectedTime == time,
          onSelected: isBusy ? null : (selected) => setState(() => _selectedTime = time),
          selectedColor: const Color(0xFF9D59FF),
          backgroundColor: const Color(0xFF1E1E2C),
          labelStyle: TextStyle(color: isBusy ? Colors.white24 : Colors.white),
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String text) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)));
  InputDecoration _inputDecoration() => InputDecoration(filled: true, fillColor: const Color(0xFF1E1E2C), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF9D59FF))));
  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}

// --- GOOGLE MAP SCREEN ---
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
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: studios.map((s) {
          return Marker(
            markerId: MarkerId(s['id']),
            position: LatLng(s['lat'], s['lng']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: s['name'],
              snippet: s['address'],
              onTap: () {
                onStudioSelected(s['id']);
                Navigator.pop(context);
              },
            ),
          );
        }).toSet(),
      ),
    );
  }
}