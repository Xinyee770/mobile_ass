import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../Authentication_UI/login.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  List<Map<String, dynamic>> attendanceList = [];
  List<Map<String, dynamic>> instructors = [];

  String attendanceSearch = "";

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
      final instructorData = await supabase.from('instructor').select();

      final attendanceData = await supabase
          .from('attendance')
          .select()
          .order('attendance_date', ascending: false);

      setState(() {
        courses = List<Map<String, dynamic>>.from(courseData);
        users = List<Map<String, dynamic>>.from(userData);
        bookings = List<Map<String, dynamic>>.from(bookingData);
        payments = List<Map<String, dynamic>>.from(paymentData);
        attendanceList = List<Map<String, dynamic>>.from(attendanceData);
        instructors = List<Map<String, dynamic>>.from(instructorData);
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
    final locations = ['Studio A (Setapak)', 'Studio B (Bentong)', 'Studio C (KL)'];

    return Padding(
      padding:  EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: selectedLocation,
        dropdownColor: cardBg,
        style:  TextStyle(color: Colors.white),
        hint: Text(
          "Location",
          style: TextStyle(color: Colors.grey),
        ),
        decoration: InputDecoration(
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

  Widget instructorDropdown({
    required int? selectedInstructorId,
    required Function(int?) onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: selectedInstructorId,
        dropdownColor: cardBg,
        iconEnabledColor: Colors.grey,
        style: TextStyle(color: Colors.white),
        hint: Text(
          "Instructor",
          style: TextStyle(color: Colors.grey),
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.person, color: accent),
          filled: true,
          fillColor: Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: instructors.map((instructor) {
          return DropdownMenuItem<int>(
            value: instructor['instructor_id'],
            child: Text(
              instructor['instructor_name'] ?? "Unknown Instructor",
              style: TextStyle(color: Colors.white),
            ),
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
  // EXPORT PDF
  // =========================

  Future<void> generateAdminReportPDF({
    required double totalRevenue,
    required int activeMembers,
    required int totalClasses,
    required int totalBookings,
    required String topClassName,
    required int maxBooking,
    required double avgRevenue,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Admin Analytics Report",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  "Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                ),
                pw.Divider(),
                pw.SizedBox(height: 16),

                reportRow("Total Revenue", "RM ${totalRevenue.toStringAsFixed(2)}"),
                reportRow("Active Members", activeMembers.toString()),
                reportRow("Total Classes", totalClasses.toString()),
                reportRow("Total Bookings", totalBookings.toString()),
                reportRow("Top Class", topClassName),
                reportRow("Peak Booking", "$maxBooking bookings"),
                reportRow("Average Revenue", "RM ${avgRevenue.toStringAsFixed(2)}"),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget reportRow(String title, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(value),
        ],
      ),
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
                final instructor = instructors.firstWhere(
                      (i) =>
                  i['instructor_id'].toString() ==
                      course['instructor_id'].toString(),
                  orElse: () => {},
                );

                final instructorName = instructor.isNotEmpty
                    ? instructor['instructor_name']?.toString() ?? "Unknown"
                    : "Unknown";

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
                      infoText("Instructor: $instructorName"),
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
    int? selectedInstructorId;
    final level = TextEditingController();
    final capacity = TextEditingController();
    final start = TextEditingController();
    final end = TextEditingController();
    final date = TextEditingController();
    String? selectedLocation;
    String? nameError;
    String? priceError;
    String? instructorError;
    String? levelError;
    String? capacityError;
    String? startError;
    String? endError;
    String? dateError;
    String? locationError;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Add Class",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            Widget errorText(String? error) {
              if (error == null) return SizedBox.shrink();

              return Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    error,
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  inputField(name, "Class Name"),
                  errorText(nameError),

                  inputField(price, "Price"),
                  errorText(priceError),

                  instructorDropdown(
                    selectedInstructorId: selectedInstructorId,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedInstructorId = value;
                      });
                    },
                  ),
                  errorText(instructorError),

                  inputField(level, "Level"),
                  errorText(levelError),

                  inputField(capacity, "Capacity"),
                  errorText(capacityError),

                  pickerField(
                    start,
                    "Start Time",
                    Icons.access_time,
                        () => pickTime(start),
                  ),
                  errorText(startError),

                  pickerField(
                    end,
                    "End Time",
                    Icons.access_time,
                        () => pickTime(end),
                  ),
                  errorText(endError),

                  pickerField(
                    date,
                    "Date",
                    Icons.calendar_today,
                        () => pickDate(date),
                  ),
                  errorText(dateError),

                  locationDropdown(
                    selectedLocation: selectedLocation,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedLocation = value;
                        locationError = null;
                      });
                    },
                  ),
                  errorText(locationError),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final lettersOnly = RegExp(r'^[a-zA-Z ]+$');
              final capacityValue = int.tryParse(capacity.text.trim());
              final priceValue = double.tryParse(price.text.trim());
              final instructorValue = selectedInstructorId;

              bool hasError = false;

              nameError = null;
              priceError = null;
              instructorError = null;
              levelError = null;
              capacityError = null;
              startError = null;
              endError = null;
              dateError = null;
              locationError = null;

              if (name.text.trim().isEmpty) {
                nameError = "Please enter class name";
                hasError = true;
              } else if (!lettersOnly.hasMatch(name.text.trim())) {
                nameError = "Class name can only contain letters";
                hasError = true;
              }

              if (price.text.trim().isEmpty) {
                priceError = "Please enter price";
                hasError = true;
              } else if (priceValue == null) {
                priceError = "Price must be a valid number";
                hasError = true;
              } else if (priceValue <= 0) {
                priceError = "Price must be greater than 0";
                hasError = true;
              }


              if (selectedInstructorId == null) {
                instructorError = "Please select instructor";
                hasError = true;
              }

              if (level.text.trim().isEmpty) {
                levelError = "Please enter level";
                hasError = true;
              } else if (!lettersOnly.hasMatch(level.text.trim())) {
                levelError = "Level must be letters";
                hasError = true;
              }

              if (capacity.text.trim().isEmpty) {
                capacityError = "Please enter capacity";
                hasError = true;
              } else if (capacityValue == null) {
                capacityError = "Capacity must be a valid number";
                hasError = true;
              } else if (capacityValue <= 0) {
                capacityError = "Capacity must be greater than 0";
                hasError = true;
              }

              if (start.text.trim().isEmpty) {
                startError = "Please select start time";
                hasError = true;
              }

              if (end.text.trim().isEmpty) {
                endError = "Please select end time";
                hasError = true;
              }

              if (date.text.trim().isEmpty) {
                dateError = "Please select date";
                hasError = true;
              }

              if (selectedLocation == null || selectedLocation!.isEmpty) {
                locationError = "Please select location";
                hasError = true;
              }

              // refresh dialog UI to show errors
              (dialogContext as Element).markNeedsBuild();

              if (hasError) return;

              try {
                await supabase.from('courses').insert({
                  'course_name': name.text.trim(),
                  'course_price': double.parse(price.text.trim()),
                  'instructor_id': selectedInstructorId,
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
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> editCourseDialog(Map<String, dynamic> course) async {
    final name = TextEditingController(text: course['course_name']?.toString() ?? '');
    final price = TextEditingController(text: course['course_price']?.toString() ?? '');
    int? selectedInstructorId = course['instructor_id'];
    final level = TextEditingController(text: course['level']?.toString() ?? '');
    final capacity = TextEditingController(text: course['capacity']?.toString() ?? '');
    final start = TextEditingController(text: course['course_start']?.toString() ?? '');
    final end = TextEditingController(text: course['course_end']?.toString() ?? '');
    final date = TextEditingController(text: course['date']?.toString() ?? '');

    String? selectedLocation = course['location']?.toString();

    if (!['Studio A (Setapak)', 'Studio B (Bentong)', 'Studio C (KL)'].contains(selectedLocation)) {
      selectedLocation = null;
    }

    String? nameError;
    String? priceError;
    String? instructorError;
    String? levelError;
    String? capacityError;
    String? startError;
    String? endError;
    String? dateError;
    String? locationError;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget errorText(String? error) {
              if (error == null) return SizedBox.shrink();

              return Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    error,
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              );
            }

            void validateAndSave() async {
              final lettersOnly = RegExp(r'^[a-zA-Z ]+$');
              final capacityValue = int.tryParse(capacity.text.trim());
              final priceValue = double.tryParse(price.text.trim());
              final instructorValue = selectedInstructorId;

              bool hasError = false;

              setDialogState(() {
                nameError = null;
                priceError = null;
                instructorError = null;
                levelError = null;
                capacityError = null;
                startError = null;
                endError = null;
                dateError = null;
                locationError = null;

                if (name.text.trim().isEmpty) {
                  nameError = "Please enter class name";
                  hasError = true;
                } else if (!lettersOnly.hasMatch(name.text.trim())) {
                  nameError = "Class name can only contain letters";
                  hasError = true;
                }

                if (price.text.trim().isEmpty) {
                  priceError = "Please enter price";
                  hasError = true;
                } else if (priceValue == null) {
                  priceError = "Price must be a valid number";
                  hasError = true;
                } else if (priceValue <= 0) {
                  priceError = "Price must be greater than 0";
                  hasError = true;
                }

                if (selectedInstructorId == null) {
                  instructorError = "Please select instructor";
                  hasError = true;
                }

                if (level.text.trim().isEmpty) {
                  levelError = "Please enter level";
                  hasError = true;
                } else if (!lettersOnly.hasMatch(level.text.trim())) {
                  levelError = "Level can only contain letters";
                  hasError = true;
                }

                if (capacity.text.trim().isEmpty) {
                  capacityError = "Please enter capacity";
                  hasError = true;
                } else if (capacityValue == null) {
                  capacityError = "Capacity must be a valid number";
                  hasError = true;
                } else if (capacityValue <= 0) {
                  capacityError = "Capacity must be greater than 0";
                  hasError = true;
                }

                if (start.text.trim().isEmpty) {
                  startError = "Please select start time";
                  hasError = true;
                }

                if (end.text.trim().isEmpty) {
                  endError = "Please select end time";
                  hasError = true;
                }

                if (date.text.trim().isEmpty) {
                  dateError = "Please select date";
                  hasError = true;
                }

                if (selectedLocation == null || selectedLocation!.isEmpty) {
                  locationError = "Please select location";
                  hasError = true;
                }
              });

              if (hasError) return;

              try {
                await supabase.from('courses').update({
                  'course_name': name.text.trim(),
                  'course_price': double.parse(price.text.trim()),
                  'instructor_id': selectedInstructorId,
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
            }

            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Text(
                "Edit Class",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    inputField(name, "Class Name"),
                    errorText(nameError),

                    inputField(price, "Price"),
                    errorText(priceError),

                    instructorDropdown(
                      selectedInstructorId: selectedInstructorId,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedInstructorId = value;
                        });
                      },
                    ),
                    errorText(instructorError),

                    inputField(level, "Level"),
                    errorText(levelError),

                    inputField(capacity, "Capacity"),
                    errorText(capacityError),

                    pickerField(
                      start,
                      "Start Time",
                      Icons.access_time,
                          () => pickTime(start),
                    ),
                    errorText(startError),

                    pickerField(
                      end,
                      "End Time",
                      Icons.access_time,
                          () => pickTime(end),
                    ),
                    errorText(endError),

                    pickerField(
                      date,
                      "Date",
                      Icons.calendar_today,
                          () => pickDate(date),
                    ),
                    errorText(dateError),

                    locationDropdown(
                      selectedLocation: selectedLocation,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLocation = value;
                          locationError = null;
                        });
                      },
                    ),
                    errorText(locationError),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: validateAndSave,
                  child: Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> deleteCourse(dynamic courseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          "Confirm Delete",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to delete this class?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF9D59FF), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('courses').delete().eq('course_id', courseId);

      await loadData();

      showMsg("Class deleted successfully", color: Colors.green);
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
    final name = TextEditingController(text: user['name']?.toString() ?? '');
    final email = TextEditingController(text: user['email']?.toString() ?? '');
    final passes = TextEditingController(text: user['passes']?.toString() ?? '0');

    String? nameError;
    String? emailError;
    String? passesError;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget errorText(String? error) {
              if (error == null) return SizedBox.shrink();

              return Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    error,
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              );
            }

            Future<void> validateAndSave() async {
              final nameRegex = RegExp(r'^[a-zA-Z ]+$');
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              final passesValue = int.tryParse(passes.text.trim());

              bool hasError = false;

              setDialogState(() {
                nameError = null;
                emailError = null;
                passesError = null;

                if (name.text.trim().isEmpty) {
                  nameError = "Please enter name";
                  hasError = true;
                } else if (!nameRegex.hasMatch(name.text.trim())) {
                  nameError = "Name can only contain letters";
                  hasError = true;
                }

                if (email.text.trim().isEmpty) {
                  emailError = "Please enter email";
                  hasError = true;
                } else if (!emailRegex.hasMatch(email.text.trim())) {
                  emailError = "Please enter a valid email";
                  hasError = true;
                }

                if (passes.text.trim().isEmpty) {
                  passesError = "Please enter passes";
                  hasError = true;
                } else if (passesValue == null) {
                  passesError = "Passes must be a valid number";
                  hasError = true;
                } else if (passesValue < 0) {
                  passesError = "Passes cannot be negative";
                  hasError = true;
                }
              });

              if (hasError) return;

              try {
                await supabase.from('profiles').update({
                  'name': name.text.trim(),
                  'email': email.text.trim(),
                  'passes': passesValue,
                }).eq('id', user['id']);

                if (!mounted) return;

                Navigator.pop(dialogContext);
                await loadData();

                showMsg("User updated successfully", color: Colors.green);
              } catch (e) {
                showMsg("Update failed: $e");
              }
            }

            return AlertDialog(
              backgroundColor: cardBg,
              title: Text(
                "Edit Member",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  inputField(name, "Name"),
                  errorText(nameError),

                  inputField(email, "Email"),
                  errorText(emailError),

                  inputField(passes, "Passes"),
                  errorText(passesError),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                  onPressed: validateAndSave,
                  child: Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> deleteUser(dynamic userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text("Confirm Delete", style: TextStyle(color: Colors.white)),
        content: Text(
          "Are you sure you want to delete this user?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF9D59FF), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('profiles').delete().eq('id', userId);

      await loadData();

      showMsg("User deleted successfully", color: Colors.green);
    } catch (e) {
      showMsg("Delete failed: $e");
    }
  }

  // =========================
  // ATTENDANCE QR SCANNER
  // =========================

  Widget attendancePage() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final todayCount = attendanceList.where((r) {
      return r['attendance_date']?.toString() == today;
    }).length;

    final filteredAttendance = attendanceList.where((record) {
      final user = users.firstWhere(
            (u) => u['id'].toString() == record['user_id'].toString(),
        orElse: () => {},
      );

      final name = user.isNotEmpty
          ? user['name']?.toString().toLowerCase() ?? ''
          : '';

      final email = user.isNotEmpty
          ? user['email']?.toString().toLowerCase() ?? ''
          : '';

      final keyword = attendanceSearch.toLowerCase();

      return name.contains(keyword) || email.contains(keyword);
    }).toList();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          adminCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner, size: 80, color: accent),
                SizedBox(height: 14),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF9D59FF),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => QRScannerPage()),
                    );

                    await loadData();
                  },
                  icon: Icon(Icons.camera_alt),
                  label: Text("Start Scan"),
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          adminCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today Check-in",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                Text(
                  todayCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 10),

          TextField(
            style: TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() {
                attendanceSearch = value;
              });
            },
            decoration: InputDecoration(
              hintText: "Search attendance by name or email...",
              hintStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.search, color: accent),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Attendance History",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: loadData,
                icon: Icon(Icons.refresh, color: accent),
              ),
            ],
          ),

          SizedBox(height: 8),

          Expanded(
            child: filteredAttendance.isEmpty
                ? Center(
              child: Text(
                "No attendance records found",
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: filteredAttendance.length,
              itemBuilder: (context, index) {
                final record = filteredAttendance[index];

                final user = users.firstWhere(
                      (u) =>
                  u['id'].toString() ==
                      record['user_id'].toString(),
                  orElse: () => {},
                );

                final name = user.isNotEmpty
                    ? user['name'] ?? "Unknown Member"
                    : "Unknown Member";

                final email = user.isNotEmpty
                    ? user['email'] ?? "-"
                    : "User ID: ${record['user_id']}";

                return adminCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 34,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Date: ${record['attendance_date'] ?? '-'}",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              "Status: ${record['status'] ?? '-'}",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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

  // =========================
  // STATISTICS REPORT
  // =========================
  void showBookingChartDialog(Map<String, int> courseCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Booking Chart",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 340,
          child: bookingChart(courseCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

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
      padding: EdgeInsets.all(16),
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

          GestureDetector(
            onTap: () {
              generateAdminReportPDF(
                totalRevenue: totalRevenue.toDouble(),
                activeMembers: activeMembers,
                totalClasses: courses.length,
                totalBookings: bookings.length,
                topClassName: topClassName,
                maxBooking: maxBooking,
                avgRevenue: avgRevenue.toDouble(),
              );
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Color(0xFF9D59FF),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Tap to export PDF report",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 18),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              statCard("Active Members", activeMembers.toString(), Icons.people),
              statCard("Total Classes", courses.length.toString(), Icons.class_),

              GestureDetector(
                onTap: () {
                  showBookingChartDialog(courseCount);
                },
                child: statCard(
                  "Total Bookings",
                  bookings.length.toString(),
                  Icons.event,
                ),
              ),

              GestureDetector(
                onTap: () {
                  showBookingChartDialog(courseCount);
                },
                child: statCard("Top Class", topClassName, Icons.trending_up),
              ),

              GestureDetector(
                onTap: () {
                  showBookingChartDialog(courseCount);
                },
                child: statCard(
                  "Peak Booking",
                  "$maxBooking bookings",
                  Icons.bar_chart,
                ),
              ),

              statCard(
                "Avg Revenue",
                "RM ${avgRevenue.toStringAsFixed(2)}",
                Icons.payments,
              ),
            ],
          ),

          SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF9D59FF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () {
                showBookingChartDialog(courseCount);
              },
              icon: Icon(Icons.bar_chart),
              label: Text("View Chart"),
            ),
          ),

          SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cardBg,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () {
                generateAdminReportPDF(
                  totalRevenue: totalRevenue.toDouble(),
                  activeMembers: activeMembers,
                  totalClasses: courses.length,
                  totalBookings: bookings.length,
                  topClassName: topClassName,
                  maxBooking: maxBooking,
                  avgRevenue: avgRevenue.toDouble(),
                );
              },
              icon: Icon(Icons.picture_as_pdf),
              label: Text("Export PDF Report"),
            ),
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

  Widget bookingChart(Map<String, int> courseCount) {
    if (courseCount.isEmpty) {
      return adminCard(
        child: Center(
          child: Text(
            "No booking data",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final entries = courseCount.entries.toList();

    return Container(
      height: 320,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          minY: 0,
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: Colors.grey),
              bottom: BorderSide(color: Colors.grey),
            ),
          ),
          gridData: FlGridData(show: true),

          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                "Bookings",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  );
                },
              ),
            ),

            bottomTitles: AxisTitles(
              axisNameWidget: Text(
                "Classes",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 || index >= entries.length) {
                    return SizedBox.shrink();
                  }

                  final courseId = entries[index].key;

                  final course = courses.firstWhere(
                        (c) => c['course_id'].toString() == courseId,
                    orElse: () => {},
                  );

                  final courseName = course.isNotEmpty
                      ? course['course_name'].toString()
                      : "C$courseId";

                  final shortName = courseName.length > 6
                      ? courseName.substring(0, 6)
                      : courseName;

                  return Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      shortName,
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),

            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),

            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),

          barGroups: List.generate(entries.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entries[index].value.toDouble(),
                  width: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
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
        now.add( Duration(minutes: 15)),
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
        backgroundColor:  Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style:  TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(Icons.error, color: Colors.red, size: 60),
             SizedBox(height: 12),
            Text(
              message,
              style:  TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:  Text("OK"),
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
        backgroundColor:  Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:  Text(
          "Check-in Successful",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(Icons.check_circle, color: Colors.green, size: 70),
             SizedBox(height: 12),
            Text(
              name,
              style:  TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
             SizedBox(height: 6),
            Text(
              email,
              style:  TextStyle(color: Colors.grey),
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
            child:  Text("Done"),
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
      backgroundColor:  Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor:  Color(0xFF3B2F4F),
        title:  Text(
          "Scan Attendance QR",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme:  IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon:  Icon(Icons.image),
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
              padding:  EdgeInsets.all(20),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:  Color(0xFF9D59FF),
                  foregroundColor: Colors.white,
                  padding:  EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: scanFromImage,
                icon:  Icon(Icons.image_search),
                label:  Text("Scan QR From Image"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}