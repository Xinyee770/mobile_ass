import 'package:flutter/material.dart';
import 'Profile_UI/profile.dart';
import 'Booking_UI/booking.dart';
import 'Payment_UI/payment_read.dart';
import 'Admin_UI/admin.dart';
import 'Classes_UI/classes.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ABC APP',
      debugShowCheckedModeBanner: false,
      // --- DARK THEME SETUP ---
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // This triggers the Dark Mode
        ),
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep black background
      ),
      home: const MyHomePage(title: 'ABC APP'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double walletBalance = 0.00; // This will update from Supabase later

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Blends into the dark background
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),

      // --- DRAWER WITH DARK THEME & WALLET ---
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E), // Slightly lighter dark for the drawer
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: theme.primaryContainer.withOpacity(0.5), // Subtle purple tint
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.primary,
                child: const Icon(Icons.person, size: 40, color: Colors.white),
              ),
              accountName: const Text(
                "Welcome Back!",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              // THE WALLET CHIP
              accountEmail: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primary.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(
                      "RM ${walletBalance.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation Items
            _buildDrawerItem(Icons.person_outline, 'User Profile', const Profile()),
            _buildDrawerItem(Icons.calendar_month_outlined, 'Calendar', const BookingPage()),
            _buildDrawerItem(Icons.account_balance_wallet_outlined, 'Payment History', const PaymentHistoryPage()),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white10),
            ),

            _buildDrawerItem(Icons.admin_panel_settings_outlined, 'Admin Panel', const Admin()),
            _buildDrawerItem(Icons.settings_outlined, 'Classes', const Classes()),
          ],
        ),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A glowing effect for the dashboard icon
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primary.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(Icons.dashboard_rounded, size: 100, color: theme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'ABC Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Swipe from left to navigate',
              style: TextStyle(color: theme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for clean code
  Widget _buildDrawerItem(IconData icon, String label, Widget destination) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        Navigator.pop(context); // Closes drawer
        Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
      },
    );
  }
}