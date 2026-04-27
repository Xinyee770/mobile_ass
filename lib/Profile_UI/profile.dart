import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final supabase = Supabase.instance.client;
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String name = "User";
  String email = "-";
  int passes = 0;
  String userId = "-";
  String createdAt = "-";

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        name = data['name'] ?? "User";
        email = data['email'] ?? "-";
        passes = data['passes'] ?? 0;
        userId = user.id;

        final rawDate = data['created_at'];

        if (rawDate != null) {
          final dateTime = DateTime.parse(rawDate);
          createdAt =
          "${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)}";
        } else {
          createdAt = "-";
        }

        loading = false;
      });
    } catch (e) {
      debugPrint("Profile load error: $e");
      setState(() => loading = false);
    }
  }

  Future<void> editEmail() async {
    final controller = TextEditingController(text: email);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Edit Email", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter new email",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await supabase
                    .from('profiles')
                    .update({'email': controller.text.trim()})
                    .eq('id', userId);

                setState(() => email = controller.text.trim());

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Email updated!")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Update failed: $e")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F0F16);
    const card = Color(0xFF1E1E2C);
    const accent = Color(0xFF9D59FF);

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: accent.withOpacity(0.2),
                    child: const Icon(Icons.person, size: 45, color: Colors.white),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    userId,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Personal Info Header
            sectionHeader("Personal Info"),

            // Email row
            infoTile(
              label: "Email",
              value: email,
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey),
                onPressed: editEmail,
              ),
            ),

            infoTile(
              label: "Account Created",
              value: createdAt.toString(),
            ),

            const SizedBox(height: 20),

            // Pass Section
            sectionHeader("Membership"),

            infoTile(
              label: "Available Passes",
              value: passes.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget sectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget infoTile({
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}