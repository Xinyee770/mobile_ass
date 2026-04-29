import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Payment_UI/payment.dart';
import '../services/notification_service.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final supabase = Supabase.instance.client;

  final List<Map<String, dynamic>> studios = [
    {'id': 'A', 'name': 'Studio A (Setapak)', 'address': '38-06, Vista Danau Kota, KL', 'lat': 3.2096, 'lng': 101.7188},
    {'id': 'B', 'name': 'Studio B (Bentong)', 'address': 'No.33 Taman Orkid, Bentong', 'lat': 3.5222, 'lng': 101.9108},
    {'id': 'C', 'name': 'Studio C (KL)', 'address': 'Sunway Velocity, KL', 'lat': 3.1279, 'lng': 101.7247},
  ];

  final List<String> _allTimeSlots = [
    '09:00:00', '10:00:00', '11:00:00', '12:00:00',
    '13:00:00', '14:00:00', '15:00:00', '16:00:00',
    '17:00:00'
  ];

  List<Map<String, dynamic>> coursesWithInstructors = [];
  List<Map<String, dynamic>> displayedInstructors = [];
  List<String> busySlots = [];

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
    NotificationService().initialize();
  }

  Future<void> _loadData() async {
    try {
      final data = await supabase.from('courses').select('*, instructor(*)');
      final filteredData = (data as List).where((course) {
        final inst = course['instructor'];
        if (inst == null) return false;
        return inst['is_private'] == true || inst['is_private'] == 1;
      }).toList();

      setState(() {
        coursesWithInstructors = List<Map<String, dynamic>>.from(filteredData);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchBusySlots() async {
    if (selectedInstructorId == null) return;
    setState(() => isCheckingSlots = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    try {
      final bookingData = await supabase
          .from('booking')
          .select('start_time')
          .eq('instructor_id', selectedInstructorId)
          .eq('booking_date', dateStr)
          .neq('booking_status', 'Cancelled');

      setState(() {
        busySlots = (bookingData as List).map((e) => e['start_time'].toString()).toList();
        isCheckingSlots = false;
        _selectedTime = null;
      });
    } catch (e) {
      setState(() => isCheckingSlots = false);
    }
  }

  Future<void> _selectNearestStudio() async {
    try {
      _showSnackBar("Detecting your location...", Colors.blue);
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Please turn on your phone's GPS.", Colors.orange);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Permission denied.", Colors.red);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));

      double shortestDistance = double.infinity;
      String? closestId;

      for (var studio in studios) {
        double dist = Geolocator.distanceBetween(
            position.latitude, position.longitude, studio['lat'], studio['lng']);
        if (dist < shortestDistance) {
          shortestDistance = dist;
          closestId = studio['id'];
        }
      }

      setState(() => selectedStudioId = closestId);
      _showSnackBar("Nearest studio selected!", Colors.green);
    } catch (e) {
      _showSnackBar("Location Error: $e", Colors.red);
    }
  }

  Future<void> _submitBooking() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || _selectedTime == null) return;

      final DateFormat df = DateFormat("HH:mm:ss");
      String endTime = df.format(df.parse(_selectedTime!).add(const Duration(hours: 1)));

      final studio = studios.firstWhere((s) => s['id'] == selectedStudioId);
      final course = coursesWithInstructors.firstWhere((c) => c['course_id'] == selectedCourseId);

      final response = await supabase.from('booking').insert({
        'user_id': user.id,
        'course_id': selectedCourseId,
        'instructor_id': selectedInstructorId,
        'booking_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'start_time': _selectedTime,
        'end_time': endTime,
        'location': studio['name'],
        'booking_status': 'Confirmed',
      }).select();

      if (response.isNotEmpty) {
        try {
          String datePart = DateFormat('yyyy-MM-dd').format(selectedDate);
          DateTime classStart = DateTime.parse("$datePart $_selectedTime");

          await NotificationService().scheduleTaskReminder(
            bookingId: response[0]['booking_id'].toString(),
            taskTitle: "Private Class: ${course['course_name']}",
            taskDateTime: classStart,
            minutesBefore: 1, // notification
          );
        } catch (e) {
          debugPrint("Notification Error: $e");
        }

        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => Payment(bookingId: response[0]['booking_id'])));
      }
    } catch (e) {
      _showSnackBar("Booking failed: $e", Colors.red);
    }
  }

  Future<void> _showConfirmationDialog() async {
    final course = coursesWithInstructors.firstWhere((c) => c['course_id'] == selectedCourseId);
    final instructor = displayedInstructors.firstWhere((i) => i['instructor_id'] == selectedInstructorId);
    final studio = studios.firstWhere((s) => s['id'] == selectedStudioId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Booking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogRow("Course", course['course_name']),
            _buildDialogRow("Instructor", instructor['instructor_name']),
            _buildDialogRow("Studio", studio['name']),
            _buildDialogRow("Date", DateFormat('EEEE, d MMM yyyy').format(selectedDate)),
            _buildDialogRow("Time", _selectedTime!.substring(0, 5)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9D59FF)),
            onPressed: () {
              Navigator.pop(context);
              _submitBooking();
            },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF9D59FF);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(title: const Text("Private Lesson", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
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
            _sectionTitle("3. Instructor"),
            _buildInstructorDropdown(),
            const SizedBox(height: 24),
            _sectionTitle("4. Select Date"),
            _buildDateButton(),
            const SizedBox(height: 32),
            _sectionTitle("5. Available Times"),
            _buildTimeWrap(),
            const SizedBox(height: 12),
            Text("* Note: The duration of the class is 1 hour.", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: (_selectedTime == null || selectedStudioId == null || selectedInstructorId == null) ? null : _showConfirmationDialog,
                child: const Text("BOOK NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeWrap() {
    if (selectedInstructorId == null) return const Text("Please select an instructor", style: TextStyle(color: Colors.white54));
    if (isCheckingSlots) return const CircularProgressIndicator(color: Color(0xFF9D59FF));
    final now = DateTime.now();
    bool isToday = selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;

    return Wrap(
      spacing: 10, runSpacing: 10,
      children: _allTimeSlots.map((time) {
        bool isBooked = busySlots.contains(time);
        bool isPast = false;
        if (isToday) {
          final t = time.split(':');
          final slot = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, int.parse(t[0]), int.parse(t[1]));
          if (slot.isBefore(now)) isPast = true;
        }
        bool isUnavailable = isBooked || isPast;
        return ChoiceChip(
          label: Text(time.substring(0, 5), style: TextStyle(color: isUnavailable ? Colors.white24 : Colors.white, decoration: isUnavailable ? TextDecoration.lineThrough : null)),
          selected: _selectedTime == time,
          selectedColor: const Color(0xFF9D59FF),
          backgroundColor: const Color(0xFF1E1E2C),
          onSelected: isUnavailable ? null : (selected) => setState(() => _selectedTime = selected ? time : null),
        );
      }).toList(),
    );
  }

  Widget _buildStudioLocationRow() {
    return Row(children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          value: selectedStudioId, dropdownColor: const Color(0xFF1E1E2C), style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(), items: studios.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))).toList(),
          onChanged: (val) => setState(() => selectedStudioId = val),
        ),
      ),
      const SizedBox(width: 8),
      _iconButton(Icons.my_location, _selectNearestStudio),
      const SizedBox(width: 8),
      _iconButton(Icons.map_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (c) => StudioMapScreen(studios: studios, onStudioSelected: (id) => setState(() => selectedStudioId = id))))),
    ]);
  }

  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<dynamic>(
      value: selectedCourseId, dropdownColor: const Color(0xFF1E1E2C), style: const TextStyle(color: Colors.white), decoration: _inputDecoration(),
      items: coursesWithInstructors.map((c) => DropdownMenuItem(value: c['course_id'], child: Text(c['course_name']))).toList(),
      onChanged: (val) {
        setState(() {
          selectedCourseId = val;
          final course = coursesWithInstructors.firstWhere((c) => c['course_id'] == val);
          displayedInstructors = [course['instructor']];
          selectedInstructorId = null;
          busySlots = [];
        });
      },
    );
  }

  Widget _buildInstructorDropdown() {
    return DropdownButtonFormField<dynamic>(
      value: selectedInstructorId, dropdownColor: const Color(0xFF1E1E2C), style: const TextStyle(color: Colors.white), decoration: _inputDecoration(),
      items: displayedInstructors.map((inst) => DropdownMenuItem(value: inst['instructor_id'], child: Text(inst['instructor_name']))).toList(),
      onChanged: (val) { setState(() => selectedInstructorId = val); _fetchBusySlots(); },
    );
  }

  Widget _buildDateButton() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
        if (picked != null) { setState(() => selectedDate = picked); _fetchBusySlots(); }
      },
      child: Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(DateFormat('EEEE, d MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.white)),
          const Icon(Icons.calendar_today, color: Color(0xFF9D59FF), size: 20),
        ]),
      ),
    );
  }

  Widget _buildDialogRow(String label, String val) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13))), Expanded(child: Text(": $val", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)))]));
  Widget _iconButton(IconData i, Function() onTap) => Container(decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)), child: IconButton(icon: Icon(i, color: const Color(0xFF9D59FF)), onPressed: onTap));
  Widget _sectionTitle(String text) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)));
  InputDecoration _inputDecoration() => InputDecoration(filled: true, fillColor: const Color(0xFF1E1E2C), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));
  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}

class StudioMapScreen extends StatelessWidget {
  final List<Map<String, dynamic>> studios;
  final Function(String) onStudioSelected;
  const StudioMapScreen({super.key, required this.studios, required this.onStudioSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Studio Locations", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: GoogleMap(
        myLocationEnabled: true, initialCameraPosition: CameraPosition(target: LatLng(studios[0]['lat'], studios[0]['lng']), zoom: 10),
        markers: studios.map((s) => Marker(
          markerId: MarkerId(s['id']), position: LatLng(s['lat'], s['lng']),
          infoWindow: InfoWindow(title: s['name'], snippet: s['address'], onTap: () { onStudioSelected(s['id']); Navigator.pop(context); }),
        )).toSet(),
      ),
    );
  }
}