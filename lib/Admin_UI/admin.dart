import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Authentication_UI/login.dart';

class Admin extends StatefulWidget {
  const Admin({super.key});

  @override
  State<Admin> createState() => _AdminState();
}

class _AdminState extends State<Admin> {
  final supabase = Supabase.instance.client;

  final Color darkBg =  Color(0xFF1A1A1A);
  final Color cardBg =  Color(0xFF242424);
  final Color purple =  Color(0xFF3B2F4F);
  final Color accent =  Color(0xFFC7A6FF);

  int selectedIndex = 0;
  bool loading = true;

  List<Map<String, dynamic>> courses = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> payments = [];

  final TextEditingController searchController = TextEditingController();
  String searchText = "";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // Fetch profile to members tab
  Future<List<dynamic>> fetchMembers() async {
    final data = await supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    return data;
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    try {
      final courseData = await supabase.from('courses').select();
      final userData = await supabase.from('profiles').select();
      final bookingData = await supabase.from('booking').select();
      final paymentData = await supabase.from('payment').select();

      setState(() {
        courses = List<Map<String, dynamic>>.from(courseData);
        users = List<Map<String, dynamic>>.from(userData);
        bookings = List<Map<String, dynamic>>.from(bookingData);
        payments = List<Map<String, dynamic>>.from(paymentData);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      showMsg("Error loading data: $e");
    }
  }

  void showMsg(String msg, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      coursesPage(),
      membersPage(),
      attendancePage(),
      analyticsPage(),
    ];

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: purple,
        title:  Text(
          "Admin Panel",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: loadData,
            icon: Icon(Icons.refresh, color: Colors.white),
          ),

          IconButton(
            onPressed: signOut,
            icon: Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        backgroundColor:  Color(0xFF202020),
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => selectedIndex = index);
        },
        items:  [
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: "Classes"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Members"),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: "Scan",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Stats"),
        ],
      ),
    );
  }

  // =========================
  // VALIDATION
  // =========================

  bool validateCourse({
    required TextEditingController name,
    required TextEditingController price,
    required TextEditingController instructor,
    required TextEditingController level,
    required TextEditingController capacity,
    required TextEditingController start,
    required TextEditingController end,
    required TextEditingController date,
    required String? location,
  }) {
    if (name.text.trim().isEmpty) {
      showMsg("Please enter class name");
      return false;
    }

    if (double.tryParse(price.text.trim()) == null ||
        double.parse(price.text.trim()) <= 0) {
      showMsg("Please enter valid price");
      return false;
    }

    if (int.tryParse(instructor.text.trim()) == null) {
      showMsg("Please enter valid instructor ID");
      return false;
    }

    if (level.text.trim().isEmpty) {
      showMsg("Please enter level");
      return false;
    }

    if (int.tryParse(capacity.text.trim()) == null ||
        int.parse(capacity.text.trim()) <= 0) {
      showMsg("Please enter valid capacity");
      return false;
    }

    if (start.text.trim().isEmpty) {
      showMsg("Please select start time");
      return false;
    }

    if (end.text.trim().isEmpty) {
      showMsg("Please select end time");
      return false;
    }

    if (date.text.trim().isEmpty) {
      showMsg("Please select date");
      return false;
    }

    if (location == null || location.isEmpty) {
      showMsg("Please select location");
      return false;
    }

    return true;
  }

  // =========================
  // PICKER FUNCTIONS
  // =========================

  Future<void> pickTime(TextEditingController controller) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      final formatted =
          "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00";
      controller.text = formatted;
    }
  }

  Future<void> pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text =
      "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  // =========================
  // PICKER FIELD UI
  // =========================

  Widget pickerField(
      TextEditingController controller,
      String hint,
      IconData icon,
      VoidCallback onTap,
      ) {
    return Padding(
      padding:  EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        style:  TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:  TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: accent),
          suffixIcon:  Icon(Icons.arrow_drop_down, color: Colors.grey),
          filled: true,
          fillColor:  Color(0xFF1A1A1A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget locationDropdown({
    required String? selectedLocation,
    required Function(String?) onChanged,
  }) {
    final locations = ['Studio A', 'Studio B', 'Studio C'];

    return Padding(
      padding:  EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: selectedLocation,
        dropdownColor: cardBg,
        style:  TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Location",
          hintStyle:  TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.location_on, color: accent),
          filled: true,
          fillColor:  Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: locations.map((location) {
          return DropdownMenuItem(
            value: location,
            child: Text(location),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }


  // =========================
  // COURSES CRUD
  // =========================

  Widget coursesPage() {
    return Padding(
      padding:  EdgeInsets.all(16),
      child: Column(
        children: [
          titleRow("Class Management", "Add Class", addCourseDialog),
           SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];

                return adminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course['course_name']?.toString() ?? 'No Class Name',
                        style:  TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                       SizedBox(height: 12),

                      infoText("Price: RM ${course['course_price'] ?? 0}"),
                      infoText("Level: ${course['level'] ?? '-'}"),
                      infoText("Capacity: ${course['capacity'] ?? '-'}"),
                      infoText("Instructor ID: ${course['instructor_id'] ?? '-'}",),
                      infoText("Date: ${course['date'] ?? '-'}"),
                      infoText("Time: ${course['course_start'] ?? '-'} - ${course['course_end'] ?? '-'}",),
                      infoText("Location: ${course['location'] ?? '-'}"),

                      SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: actionButton(
                              "Edit",
                              Icons.edit,
                              Color(0xFF4A4A4A),
                                  () => editCourseDialog(course),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: actionButton("Delete", Icons.delete, Color(0xFFC91F1F), () => deleteCourse(course['course_id']),),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> addCourseDialog() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final instructor = TextEditingController();
    final level = TextEditingController();
    final capacity = TextEditingController();
    final start = TextEditingController();
    final end = TextEditingController();
    final date = TextEditingController();

    String? selectedLocation;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:  Text(
          "Add Class",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  inputField(name, "Class Name"),
                  inputField(price, "Price"),
                  inputField(instructor, "Instructor ID"),
                  inputField(level, "Level"),
                  inputField(capacity, "Capacity"),
                  pickerField(start, "Start Time", Icons.access_time, () => pickTime(start),),
                  pickerField(end, "End Time", Icons.access_time, () => pickTime(end),),
                  pickerField(date, "Date", Icons.calendar_today, () => pickDate(date),),
                  locationDropdown(
                    selectedLocation: selectedLocation,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedLocation = value;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:  Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              if (!validateCourse(
                name: name,
                price: price,
                instructor: instructor,
                level: level,
                capacity: capacity,
                start: start,
                end: end,
                date: date,
                location: selectedLocation,
              )) {
                return;
              }

              try {
                await supabase.from('courses').insert({
                  'course_name': name.text.trim(),
                  'course_price': double.parse(price.text.trim()),
                  'instructor_id': int.parse(instructor.text.trim()),
                  'level': level.text.trim(),
                  'capacity': int.parse(capacity.text.trim()),
                  'course_start': start.text.trim(),
                  'course_end': end.text.trim(),
                  'date': date.text.trim(),
                  'location': selectedLocation,
                });

                if (!mounted) return;

                Navigator.pop(dialogContext);
                await loadData();
                showMsg("Class added successfully", color: Colors.green);
              } catch (e) {
                showMsg("Add failed: $e");
                debugPrint("ADD COURSE ERROR: $e");
              }
            },
            child:  Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> editCourseDialog(Map<String, dynamic> course) async {
    final name = TextEditingController(text: course['course_name']?.toString() ?? '',);
    final price = TextEditingController(text: course['course_price']?.toString() ?? '',);
    final instructorId = TextEditingController(text: course['instructor_id']?.toString() ?? '',);
    final level = TextEditingController(text: course['level']?.toString() ?? '',);
    final capacity = TextEditingController(text: course['capacity']?.toString() ?? '',);
    final start = TextEditingController(text: course['course_start']?.toString() ?? '',);
    final end = TextEditingController(text: course['course_end']?.toString() ?? '',);
    final date = TextEditingController(text: course['date']?.toString() ?? '',);

    String? selectedLocation = course['location']?.toString();

    if (!['Studio A', 'Studio B', 'Studio C'].contains(selectedLocation)) {
      selectedLocation = null;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title:  Text(
          "Edit Class",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  inputField(name, "Class Name"),
                  inputField(price, "Price"),
                  inputField(instructorId, "Instructor ID"),
                  inputField(level, "Level"),
                  inputField(capacity, "Capacity"),
                  pickerField(start, "Start Time", Icons.access_time, () => pickTime(start),),
                  pickerField(end, "End Time", Icons.access_time, () => pickTime(end),),
                  pickerField(date, "Date", Icons.calendar_today, () => pickDate(date),),
                  locationDropdown(
                    selectedLocation: selectedLocation,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedLocation = value;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:  Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              if (!validateCourse(
                name: name,
                price: price,
                instructor: instructorId,
                level: level,
                capacity: capacity,
                start: start,
                end: end,
                date: date,
                location: selectedLocation,
              )) {
                return;
              }

              try {
                await supabase.from('courses').update({
                  'course_name': name.text.trim(),
                  'course_price': double.parse(price.text.trim()),
                  'instructor_id': int.parse(instructorId.text.trim()),
                  'level': level.text.trim(),
                  'capacity': int.parse(capacity.text.trim()),
                  'course_start': start.text.trim(),
                  'course_end': end.text.trim(),
                  'date': date.text.trim(),
                  'location': selectedLocation,
                }).eq('course_id', course['course_id']);

                if (!mounted) return;

                Navigator.of(dialogContext).pop();
                await loadData();

                showMsg("Class updated successfully", color: Colors.green);
              } catch (e) {
                showMsg("Update failed: $e");
                debugPrint("UPDATE COURSE ERROR: $e");
              }
            },
            child:  Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> deleteCourse(dynamic courseId) async {
    try {
      await supabase.from('courses').delete().eq('course_id', courseId);
      await loadData();
      showMsg("Class deleted successfully");
    } catch (e) {
      showMsg("Delete failed: $e");
      debugPrint("DELETE COURSE ERROR: $e");
    }
  }

  // =========================
  // MEMBER DATABASE
  // =========================

  Widget membersPage() {
    final filteredUsers = users.where((user) {
      final keyword = searchText.toLowerCase();
      final name = user['name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';

      return name.contains(keyword) || email.contains(keyword);
    }).toList();

    return Padding(
      padding:  EdgeInsets.all(16),
      child: Column(
        children: [
           Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Member Database",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
           SizedBox(height: 12),
          TextField(
            controller: searchController,
            style:  TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() => searchText = value);
            },
            decoration: InputDecoration(
              hintText: "Search user by name, email, phone...",
              hintStyle:  TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.search, color: accent),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
           SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];

                return adminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'No Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      infoText("Email: ${user['email'] ?? '-'}"),
                      infoText("Passes: ${user['passes'] ?? 0}"),
                      infoText("Role: ${user['role'] ?? 'member'}"),
                      infoText("User ID: ${user['id']}"),
                       SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: actionButton(
                              "Edit",
                              Icons.edit,
                              Colors.grey.shade800,
                                  () => editUserDialog(user),
                            ),
                          ),
                           SizedBox(width: 10),
                          Expanded(
                            child: actionButton(
                              "Delete",
                              Icons.delete,
                              Colors.red.shade900,
                                  () => deleteUser(user['user_id']),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> editUserDialog(Map<String, dynamic> user) async {
    final name = TextEditingController(text: user['name']);
    final email = TextEditingController(text: user['email']);
    final passes = TextEditingController(text: user['passes'].toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        title: const Text("Edit Member", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            inputField(name, "Name"),
            inputField(email, "Email"),
            inputField(passes, "Passes"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            onPressed: () async {
              try {
                await supabase
                    .from('profiles')
                    .update({
                  'name': name.text.trim(),
                  'email': email.text.trim(),
                  'passes': int.tryParse(passes.text.trim()) ?? 0,
                })
                    .eq('id', user['id']);

                Navigator.pop(context);
                await loadData();

                showMsg("Member updated successfully", color: Colors.green);
              } catch (e) {
                showMsg("Update failed: $e");
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> deleteUser(dynamic userId) async {
    await supabase.from('profiles').delete().eq('id', userId);
    loadData();
  }

  // =========================
  // ATTENDANCE QR SCANNER
  // =========================

  Widget attendancePage() {
    return Center(
      child: Padding(
        padding:  EdgeInsets.all(20),
        child: adminCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 90, color: accent),
               SizedBox(height: 16),
               Text(
                "Attendance Tracking",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
               SizedBox(height: 8),
               Text(
                "Scan member QR code using camera.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
               SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: purple),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) =>  QRScannerPage()),
                  );
                },
                icon:  Icon(Icons.camera_alt),
                label:  Text("Start Scan"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // STATISTICS REPORT
  // =========================

  Widget analyticsPage() {
    double totalRevenue = 0;

    for (final p in payments) {
      totalRevenue += double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
    }

    final Map<String, int> courseCount = {};

    for (final b in bookings) {
      final courseId = b['course_id']?.toString() ?? 'Unknown';
      courseCount[courseId] = (courseCount[courseId] ?? 0) + 1;
    }

    String popularCourseId = "-";
    int maxBooking = 0;

    courseCount.forEach((key, value) {
      if (value > maxBooking) {
        popularCourseId = key;
        maxBooking = value;
      }
    });

    return Padding(
      padding:  EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          statCard("Total Members", users.length.toString(), Icons.people),
          statCard("Total Classes", courses.length.toString(), Icons.class_),
          statCard("Total Bookings", bookings.length.toString(), Icons.event),
          statCard(
            "Total Revenue",
            "RM ${totalRevenue.toStringAsFixed(2)}",
            Icons.account_balance_wallet,
          ),
          statCard("Popular Course ID", popularCourseId, Icons.trending_up),
          statCard("Peak Booking", "$maxBooking bookings", Icons.bar_chart),
        ],
      ),
    );
  }

  // =========================
  // REUSABLE WIDGETS
  // =========================

  Widget titleRow(String title, String buttonText, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style:  TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: purple),
          onPressed: onPressed,
          icon:  Icon(Icons.add),
          label: Text(buttonText),
        ),
      ],
    );
  }

  Widget adminCard({required Widget child}) {
    return Container(
      margin:  EdgeInsets.only(bottom: 16),
      padding:  EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:  LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset:  Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }

  Widget actionButton(
      String text,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
    );
  }

  Widget statCard(String title, String value, IconData icon) {
    return adminCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent, size: 36),
           SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style:  TextStyle(color: Colors.grey),
          ),
           SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style:  TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget inputField(TextEditingController controller, String hint) {
    return Padding(
      padding:  EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style:  TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:  TextStyle(color: Colors.grey),
          filled: true,
          fillColor:  Color(0xFF1A1A1A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget infoText(String text) {
    return Padding(
      padding:  EdgeInsets.only(top: 5),
      child: Text(text, style:  TextStyle(color: Colors.grey)),
    );
  }
}

// =========================
// QR SCANNER PAGE
// =========================

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final supabase = Supabase.instance.client;
  bool scanned = false;

  Future<void> saveAttendance(String qrValue) async {
    try {
      int? userId;

      print("QR VALUE: $qrValue");
      final match = RegExp(r'\d+').firstMatch(qrValue);

      if (match != null) {
        userId = int.tryParse(match.group(0)!);
      }

      if (userId == null) {
        throw Exception("Invalid QR code");
      }

      await supabase.from('attendance').insert({
        'user_id': userId,
        'status': 'Present',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User $userId checked in")),
      );

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scan failed: $e")),
      );

      setState(() => scanned = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F4F),
        title: const Text("Scan Attendance QR"),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (scanned) return;

          final barcode = capture.barcodes.first;
          final value = barcode.rawValue;

          if (value != null) {
            scanned = true;
            saveAttendance(value);
          }
        },
      ),
    );
  }
}