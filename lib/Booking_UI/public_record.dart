import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'public_update.dart'; // Ensure this matches your filename

class PublicRecord extends StatefulWidget {
  const PublicRecord({super.key});

  @override
  State<PublicRecord> createState() => _PublicRecordState();
}

class _PublicRecordState extends State<PublicRecord> {
  final supabase = Supabase.instance.client;
  String activeFilter = "ALL";

  Future<List<dynamic>> _fetchPublicBookings() async {
    try {
      final response = await supabase
          .from('booking')
          .select('''
            *,
            courses(course_name),
            instructor(instructor_name, is_private)
          ''')
          .order('booking_date', ascending: false);

      final allBookings = (response as List).where((booking) {
        final inst = booking['instructor'];
        return inst != null && (inst['is_private'] == false || inst['is_private'] == null);
      }).toList();

      if (activeFilter == "ALL") return allBookings;
      return allBookings.where((b) => b['booking_status'].toString().toUpperCase() == activeFilter).toList();
    } catch (e) {
      debugPrint("Fetch error: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Public History", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _fetchPublicBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF9D59FF)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No records found", style: TextStyle(color: Colors.white30)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) => _buildClassCard(snapshot.data![index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: ["ALL", "CONFIRMED", "CANCELLED"].map((status) {
          bool isActive = activeFilter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(status),
              selected: isActive,
              onSelected: (val) => setState(() => activeFilter = status),
              selectedColor: const Color(0xFF5E498A),
              backgroundColor: const Color(0xFF1E1E2C),
              labelStyle: TextStyle(color: isActive ? Colors.white : Colors.white30, fontSize: 12, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClassCard(dynamic booking) {
    final String status = (booking['booking_status'] ?? "Confirmed").toString();
    final bool isCancelled = status.toLowerCase() == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCancelled ? const Color(0xFF3B1E1E) : const Color(0xFF1B2C2B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      color: isCancelled ? const Color(0xFFFF5959) : const Color(0xFF57C5B6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
              // --- NAVIGATION BUTTON ---
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white30, size: 28),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PublicUpdate(booking: booking)),
                  ).then((_) => setState(() {})); // Refresh list on return
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(booking['courses']?['course_name'] ?? "Public Class",
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          _iconDetail(Icons.calendar_today_outlined, booking['booking_date'] ?? ""),
          const SizedBox(height: 10),
          _iconDetail(Icons.access_time, "${booking['start_time']} - ${booking['end_time']}"),
          const SizedBox(height: 10),
          _iconDetail(Icons.location_on_outlined, booking['location'] ?? "Main Studio"),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("NOTES", style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("No notes.", style: TextStyle(color: Colors.white30, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.white30, size: 18),
                  const SizedBox(width: 8),
                  Text(booking['instructor']?['instructor_name'] ?? "TBA",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _iconDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white30, size: 18),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}