import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Admin extends StatefulWidget {
  const Admin({super.key});

  @override
  State<Admin> createState() => _AdminState();
}

class _AdminState extends State<Admin> {
  final supabase = Supabase.instance.client;

  final Color darkBg = const Color(0xFF1A1A1A);
  final Color cardBg = const Color(0xFF242424);
  final Color purple = const Color(0xFF3B2F4F);
  final Color accent = const Color(0xFFC7A6FF);

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

  Future<void> loadData() async {
    setState(() => loading = true);

    try {
      final courseData = await supabase.from('courses').select();
      final userData = await supabase.from('users').select();
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

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
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
        title: const Text(
          "Admin Panel",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        backgroundColor: const Color(0xFF202020),
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: "Classes",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Members",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: "Scan",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Stats",
          ),
        ],
      ),
    );
  }

  // =========================
  // COURSES CRUD
  // =========================

  Widget coursesPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          titleRow("Class Management", "Add Class", addCourseDialog),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];

                return adminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['course_name']?.toString() ?? 'No Course Name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),

                      infoText("Price: RM ${course['course_price'] ?? 0}"),
                      infoText("Instructor: ${course['instructor'] ?? '-'}"),
                      infoText("Schedule: ${course['schedule'] ?? '-'}"),
                      infoText("Level: ${course['level'] ?? '-'}"),
                      infoText("Capacity: ${course['capacity'] ?? '-'}"),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: actionButton(
                              "Edit",
                              Icons.edit,
                              const Color(0xFF4A4A4A),
                                  () => editCourseDialog(course),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: actionButton(
                              "Delete",
                              Icons.delete,
                              const Color(0xFFC91F1F),
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
    final schedule = TextEditingController();
    final level = TextEditingController();
    final capacity = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Add Class",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              inputField(name, "Class Name"),
              inputField(price, "Price"),
              inputField(instructor, "Instructor"),
              inputField(schedule, "Schedule"),
              inputField(level, "Level"),
              inputField(capacity, "Capacity"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              await supabase.from('courses').insert({
                'course_name': name.text.trim(),
                'course_price': double.tryParse(price.text.trim()) ?? 0,
                'instructor': instructor.text.trim(),
                'schedule': schedule.text.trim(),
                'level': level.text.trim(),
                'capacity': int.tryParse(capacity.text.trim()) ?? 20,
              });

              if (!mounted) return;
              Navigator.of(dialogContext).pop();
              await loadData();

              showMsg("Class added successfully");
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> editCourseDialog(Map<String, dynamic> course) async {
    final name = TextEditingController(text: course['course_name']?.toString() ?? '');
    final price = TextEditingController(text: course['course_price']?.toString() ?? '');
    final instructor = TextEditingController(text: course['instructor']?.toString() ?? '');
    final schedule = TextEditingController(text: course['schedule']?.toString() ?? '');
    final level = TextEditingController(text: course['level']?.toString() ?? '');
    final capacity = TextEditingController(text: course['capacity']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Edit Class",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              inputField(name, "Class Name"),
              inputField(price, "Price"),
              inputField(instructor, "Instructor"),
              inputField(schedule, "Schedule"),
              inputField(level, "Level"),
              inputField(capacity, "Capacity"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              await supabase.from('courses').update({
                'course_name': name.text.trim(),
                'course_price': double.tryParse(price.text.trim()) ?? 0,
                'instructor': instructor.text.trim(),
                'schedule': schedule.text.trim(),
                'level': level.text.trim(),
                'capacity': int.tryParse(capacity.text.trim()) ?? 20,
              }).eq('course_id', course['course_id']);

              if (!mounted) return;
              Navigator.of(dialogContext).pop();
              await loadData();

              showMsg("Class updated successfully");
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> deleteCourse(dynamic courseId) async {
    await supabase.from('courses').delete().eq('course_id', courseId);
    await loadData();
    showMsg("Class deleted");
  }

  // =========================
  // MEMBER DATABASE
  // =========================

  Widget membersPage() {
    final filteredUsers = users.where((user) {
      final keyword = searchText.toLowerCase();
      final name = user['name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      final phone = user['phone']?.toString().toLowerCase() ?? '';

      return name.contains(keyword) ||
          email.contains(keyword) ||
          phone.contains(keyword);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Align(
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
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() => searchText = value);
            },
            decoration: InputDecoration(
              hintText: "Search user by name, email, phone...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.search, color: accent),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                        user['name']?.toString() ?? 'No Name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      infoText("Email: ${user['email'] ?? '-'}"),
                      infoText("Phone: ${user['phone'] ?? '-'}"),
                      infoText("Role: ${user['role'] ?? 'member'}"),
                      infoText("User ID: ${user['user_id']}"),
                      const SizedBox(height: 12),
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
                          const SizedBox(width: 10),
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
    final name = TextEditingController(text: user['name']?.toString());
    final email = TextEditingController(text: user['email']?.toString());
    final phone = TextEditingController(text: user['phone']?.toString());
    final role = TextEditingController(text: user['role']?.toString() ?? 'member');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        title: const Text("Edit Member", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              inputField(name, "Name"),
              inputField(email, "Email"),
              inputField(phone, "Phone"),
              inputField(role, "Role"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            onPressed: () async {
              await supabase.from('users').update({
                'name': name.text,
                'email': email.text,
                'phone': phone.text,
                'role': role.text,
              }).eq('user_id', user['user_id']);

              Navigator.of(context, rootNavigator: true).pop();
              loadData();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> deleteUser(dynamic userId) async {
    await supabase.from('users').delete().eq('user_id', userId);
    loadData();
  }

  // =========================
  // ATTENDANCE QR SCANNER
  // =========================

  Widget attendancePage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: adminCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 90, color: accent),
              const SizedBox(height: 16),
              const Text(
                "Attendance Tracking",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Scan member QR code using camera.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: purple),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QRScannerPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text("Start Scan"),
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
      padding: const EdgeInsets.all(16),
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
          statCard(
            "Popular Course ID",
            popularCourseId,
            Icons.trending_up,
          ),
          statCard(
            "Peak Booking",
            "$maxBooking bookings",
            Icons.bar_chart,
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: purple),
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(buttonText),
        ),
      ],
    );
  }

  Widget adminCard({required Widget child}) {
    return Card(
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget actionButton(
      String text,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: color,foregroundColor: Colors.white,),
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
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget infoText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey),
      ),
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
      final userId = int.tryParse(qrValue);

      if (userId == null) {
        throw Exception("Invalid QR code. QR should contain user_id.");
      }

      await supabase.from('attendance').insert({
        'user_id': userId,
        'status': 'Present',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance recorded successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

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