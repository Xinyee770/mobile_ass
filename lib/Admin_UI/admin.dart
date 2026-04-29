import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

  final TextEditingController classSearchController = TextEditingController();
  String classSearchText = "";

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
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Users"),
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
    final nameText = name.text.trim();
    final priceText = price.text.trim();
    final instructorText = instructor.text.trim();
    final levelText = level.text.trim();
    final capacityText = capacity.text.trim();

    final lettersOnly = RegExp(r'^[a-zA-Z ]+$');
    final numbersOnly = RegExp(r'^[0-9]+$');
    final decimalOnly = RegExp(r'^[0-9]+(\.[0-9]+)?$');

    if (nameText.isEmpty) {
      showMsg("Please enter class name");
      return false;
    }

    if (!lettersOnly.hasMatch(nameText)) {
      showMsg("Class name can only contain letters");
      return false;
    }

    if (priceText.isEmpty) {
      showMsg("Please enter price");
      return false;
    }

    if (!decimalOnly.hasMatch(priceText)) {
      showMsg("Price can only contain numbers");
      return false;
    }

    if (double.parse(priceText) <= 0) {
      showMsg("Price must be greater than 0");
      return false;
    }

    if (instructorText.isEmpty) {
      showMsg("Please enter instructor ID");
      return false;
    }

    if (!numbersOnly.hasMatch(instructorText)) {
      showMsg("Instructor ID can only contain numbers");
      return false;
    }

    if (levelText.isEmpty) {
      showMsg("Please enter level");
      return false;
    }

    if (!lettersOnly.hasMatch(levelText)) {
      showMsg("Level can only contain letters");
      return false;
    }

    if (capacityText.isEmpty) {
      showMsg("Please enter capacity");
      return false;
    }

    if (!numbersOnly.hasMatch(capacityText)) {
      showMsg("Capacity can only contain numbers");
      return false;
    }

    if (int.parse(capacityText) <= 0) {
      showMsg("Capacity must be greater than 0");
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
  // DATE AND TIME FUNCTIONS
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
  // DATE AND TIME UI
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
      MaterialPageRoute(builder: (_) =>  LoginPage()),
    );
  }


  // =========================
  // CLASSES CRUD
  // =========================

  Widget coursesPage() {
    final filteredCourses = courses.where((course) {
      final keyword = classSearchText.toLowerCase();
      final name = course['course_name']?.toString().toLowerCase() ?? '';
      final level = course['level']?.toString().toLowerCase() ?? '';
      final location = course['location']?.toString().toLowerCase() ?? '';

      return name.contains(keyword) ||
          level.contains(keyword) ||
          location.contains(keyword);
    }).toList();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          titleRow("Class Management", "Add Class", addCourseDialog),
          SizedBox(height: 16),

          TextField(
            controller: classSearchController,
            style: TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() => classSearchText = value);
            },
            decoration: InputDecoration(
              hintText: "Search class by name, level, location...",
              hintStyle: TextStyle(color: Colors.grey),
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
              itemCount: filteredCourses.length,
              itemBuilder: (context, index) {
                final course = filteredCourses[index];

                return adminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['course_name']?.toString() ?? 'No Class Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12),
                      infoText("Price: RM ${course['course_price'] ?? 0}"),
                      infoText("Level: ${course['level'] ?? '-'}"),
                      infoText("Capacity: ${course['capacity'] ?? '-'}"),
                      infoText("Instructor ID: ${course['instructor_id'] ?? '-'}"),
                      infoText("Date: ${course['date'] ?? '-'}"),
                      infoText(
                        "Time: ${course['course_start'] ?? '-'} - ${course['course_end'] ?? '-'}",
                      ),
                      infoText("Location: ${course['location'] ?? '-'}"),
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: actionButton(
                              "Edit",
                              Icons.edit,
                              Color(0xFF9D59FF),
                                  () => editCourseDialog(course),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: actionButton(
                              "Delete",
                              Icons.delete,
                              Color(0xFFC91F1F),
                                  () => deleteCourse(course['course_id']),
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

  String selectedRole = "all";

  Widget membersPage() {
    final filteredUsers = users.where((user) {
      final keyword = searchText.toLowerCase();
      final name = user['name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';

      //ROLE FILTER
      if (selectedRole != "all" && user['role'] != selectedRole) {
        return false;
      }

      return name.contains(keyword) || email.contains(keyword);
    }).toList();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "User Database",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SizedBox(height: 12),

          //FILTER BUTTONS
          Row(
            children: [
              Expanded(
                child: filterButton("All", "all"),
              ),
              SizedBox(width: 10),
              Expanded(
                child: filterButton("Members", "member"),
              ),
              SizedBox(width: 10),
              Expanded(
                child: filterButton("Admins", "admin"),
              ),
            ],
          ),

          SizedBox(height: 12),

          // SEARCH
          TextField(
            controller: searchController,
            style: TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() => searchText = value);
            },
            decoration: InputDecoration(
              hintText: "Search user by name, email...",
              hintStyle: TextStyle(color: Colors.grey),
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
                              Color(0xFF9D59FF),
                                  () => editUserDialog(user),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: actionButton(
                              "Delete",
                              Icons.delete,
                              Colors.red.shade900,
                                  () => deleteUser(user['id']),
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

  Widget filterButton(String text, String role) {
    final isSelected = selectedRole == role;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
        isSelected ? Color(0xFF9D59FF) : cardBg,
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        setState(() {
          selectedRole = role;
        });
      },
      child: Text(text),
    );
  }

  Future<void> editUserDialog(Map<String, dynamic> user) async {
    final name = TextEditingController(text: user['name']);
    final email = TextEditingController(text: user['email']);
    final passes = TextEditingController(text: user['passes'].toString());

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        title:  Text("Edit Member", style: TextStyle(color: Colors.white)),
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
            onPressed: () => Navigator.pop(dialogContext),
            child:  Text("Cancel"),
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

                Navigator.pop(dialogContext);
                await loadData();

                showMsg("Member updated successfully", color: Colors.green);
              } catch (e) {
                showMsg("Update failed: $e");
              }
            },
            child:  Text("Save"),
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
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF9D59FF),foregroundColor: Colors.white),
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

    final activeMembers =
        users.where((u) => u['role']?.toString() == 'member').length;

    final Map<String, int> courseCount = {};

    for (final b in bookings) {
      final courseId = b['course_id']?.toString() ?? '';
      if (courseId.isNotEmpty) {
        courseCount[courseId] = (courseCount[courseId] ?? 0) + 1;
      }
    }

    String topClassName = "-";
    int maxBooking = 0;

    courseCount.forEach((courseId, count) {
      if (count > maxBooking) {
        maxBooking = count;

        final course = courses.firstWhere(
              (c) => c['course_id'].toString() == courseId,
          orElse: () => {},
        );

        topClassName = course.isNotEmpty
            ? course['course_name'].toString()
            : "Course $courseId";
      }
    });

    final avgRevenue = bookings.isEmpty ? 0 : totalRevenue / bookings.length;

    return SingleChildScrollView(
      padding:  EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            "Overview Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

           SizedBox(height: 6),

           Text(
            "Overview of members, bookings and revenue",
            style: TextStyle(color: Colors.grey),
          ),

           SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding:  EdgeInsets.all(22),
            decoration: BoxDecoration(
              color:  Color(0xFF9D59FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 38),
                 SizedBox(height: 14),
                 Text(
                  "Total Revenue",
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                 SizedBox(height: 6),
                Text(
                  "RM ${totalRevenue.toStringAsFixed(2)}",
                  style:  TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

           SizedBox(height: 18),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics:  NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              statCard("Active Members", activeMembers.toString(), Icons.people),
              statCard("Total Classes", courses.length.toString(), Icons.class_),
              statCard("Total Bookings", bookings.length.toString(), Icons.event),
              statCard("Top Class", topClassName, Icons.trending_up),
              statCard("Peak Booking", "$maxBooking bookings", Icons.bar_chart),
              statCard(
                "Avg Revenue",
                "RM ${avgRevenue.toStringAsFixed(2)}",
                Icons.payments,
              ),
            ],
          ),
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
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF9D59FF),foregroundColor: Colors.white),
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
          Icon(icon, color: accent, size: 30),
          SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          SizedBox(height: 6),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
  final MobileScannerController scannerController = MobileScannerController();

  bool scanned = false;

  @override
  void initState() {
    super.initState();
    markMissedClasses();
  }

  Future<void> markMissedClasses() async {
    try {
      final now = DateTime.now();
      final currentDate = DateFormat('yyyy-MM-dd').format(now);
      final currentTime = DateFormat('HH:mm:ss').format(now);

      await supabase
          .from('booking')
          .update({'booking_status': 'Missed'})
          .eq('booking_status', 'Confirmed')
          .or(
        'booking_date.lt.$currentDate,and(booking_date.eq.$currentDate,end_time.lt.$currentTime)',
      );
    } catch (e) {
      debugPrint("Error marking missed classes: $e");
    }
  }

  Future<void> saveAttendance(String qrValue) async {
    try {
      final userId = qrValue.trim();
      final now = DateTime.now();
      final currentDate = DateFormat('yyyy-MM-dd').format(now);
      final currentTime = DateFormat('HH:mm:ss').format(now);

      final startTimeWithGrace = DateFormat('HH:mm:ss').format(
        now.add(const Duration(minutes: 15)),
      );

      if (userId.isEmpty) {
        await showErrorDialog("Invalid QR Code", "QR code is empty.");
        setState(() => scanned = false);
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('name, email')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        await showErrorDialog("Invalid QR", "User not found.");
        setState(() => scanned = false);
        return;
      }

      final existing = await supabase
          .from('attendance')
          .select()
          .eq('user_id', userId)
          .eq('attendance_date', currentDate);

      if (existing.isNotEmpty) {
        await showErrorDialog(
          "Already Checked-in",
          "This user already checked in today.",
        );
        setState(() => scanned = false);
        return;
      }

      final activeBooking = await supabase
          .from('booking')
          .update({'booking_status': 'Attended'})
          .eq('user_id', userId)
          .eq('booking_date', currentDate)
          .lte('start_time', startTimeWithGrace)
          .gte('end_time', currentTime)
          .select();

      try {
        await supabase.from('attendance').insert({
          'user_id': userId,
          'status': 'Present',
          'attendance_date': currentDate,
        });
      } catch (e) {
        await showErrorDialog(
          "Already Checked-in",
          "This user already checked in today.",
        );
        setState(() => scanned = false);
        return;
      }

      if (!mounted) return;

      final displayInfo = activeBooking.isNotEmpty
          ? "${profile['email']}\n(Booking Marked Attended)"
          : "${profile['email']}\n(General Attendance Only)";

      await showSuccessDialog(
        profile['name'] ?? 'Member',
        displayInfo,
      );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog("Scan Error", e.toString());
      setState(() => scanned = false);
    }
  }

  Future<void> showErrorDialog(String title, String message) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 60),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> showSuccessDialog(String name, String email) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Check-in Successful",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 70),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              email,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => scanned = false);
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  Future<void> scanFromImage() async {
    if (scanned) return;

    try {
      scanned = true;

      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(source: ImageSource.gallery);

      if (pickedImage == null) {
        scanned = false;
        return;
      }

      final barcodeCapture =
      await scannerController.analyzeImage(pickedImage.path);

      if (barcodeCapture == null || barcodeCapture.barcodes.isEmpty) {
        throw Exception("No QR code found in image");
      }

      final value = barcodeCapture.barcodes.first.rawValue;

      if (value == null || value.isEmpty) {
        throw Exception("QR code has no value");
      }

      await saveAttendance(value);
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog("Image Scan Failed", e.toString());
      setState(() => scanned = false);
    }
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F4F),
        title: const Text(
          "Scan Attendance QR",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: scanFromImage,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: (capture) async {
              if (scanned) return;

              final barcode = capture.barcodes.first;
              final value = barcode.rawValue;

              if (value != null && value.isNotEmpty) {
                setState(() => scanned = true);
                await saveAttendance(value);
              }
            },
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D59FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: scanFromImage,
                icon: const Icon(Icons.image_search),
                label: const Text("Scan QR From Image"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}