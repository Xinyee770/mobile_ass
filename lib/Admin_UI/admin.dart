import 'package:flutter/material.dart';

class Admin extends StatefulWidget {
  const Admin({super.key});

  @override
  State<Admin> createState() => _AdminState();
}

class _AdminState extends State<Admin> {
  // Mock Data matching your image
  final List<Map<String, dynamic>> _classes = [
    {
      "title": "Ballet Fundamentals",
      "type": "Ballet",
      "level": "Beginner",
      "duration": "60 minutes",
      "instructor": "Elena Martinez",
      "students": 18,
      "color": Colors.green
    },
    {
      "title": "Hip Hop Choreography",
      "type": "Hip Hop",
      "level": "Intermediate",
      "duration": "75 minutes",
      "instructor": "Marcus Williams",
      "students": 24,
      "color": Colors.orange
    },
    // Add more items here...
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Dance Classes",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () {}, // CRUD: Create
              icon: const Icon(Icons.add),
              label: const Text("New Class"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.builder(
          // Responsiveness: 2 columns for tablets/wide screens, 1 for small phones
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            mainAxisExtent: 280, // Height of the card
          ),
          itemCount: _classes.length,
          itemBuilder: (context, index) => _buildClassCard(_classes[index], index),
        ),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> data, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(data['title'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: data['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(data['level'],
                    style: TextStyle(color: data['color'], fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Text(data['type'], style: TextStyle(color: Colors.grey.shade500)),
          const Spacer(),

          // Details: Duration, Instructor, Students
          _infoRow(Icons.access_time, data['duration']),
          _infoRow(Icons.person_outline, data['instructor']),
          _infoRow(Icons.group_outlined, "${data['students']} students"),

          const SizedBox(height: 15),

          // CRUD Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {}, // CRUD: Update
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Edit"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () { // CRUD: Delete
                  setState(() => _classes.removeAt(index));
                },
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}