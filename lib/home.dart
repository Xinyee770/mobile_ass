import 'package:flutter/material.dart';
import 'Profile_UI/profile.dart';
import 'Booking_UI/booking.dart';
import 'Booking_UI/booking_record.dart';
import 'Booking_UI/public_booking.dart';
import 'Booking_UI/public_record.dart';
import 'Payment_UI/wallet_topup.dart';
import 'Payment_UI/FinancialHub_Page.dart';
import 'package:local_auth/local_auth.dart';
import 'utils/ui_helpers.dart';
import 'Admin_UI/admin.dart';
import 'services/wallet_service.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    // --- BRAND COLORS FROM YOUR DESIGN ---
    const Color brandPurple = Color(0xFF9D59FF); // Electric Purple
    const Color bgDeep = Color(0xFF0F0F16);      // Deep dark background
    const Color cardGrey = Color(0xFF1E1E2C);    // Charcoal surface color

    return MaterialApp(
      title: 'ABC APP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Using a dark brightness and our brand purple as the seed
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandPurple,
          primary: brandPurple,
          brightness: Brightness.dark,
          surface: cardGrey,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[900], // Default background
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          behavior: SnackBarBehavior.floating,
        ),
        scaffoldBackgroundColor: bgDeep,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
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
  final WalletService _walletService = WalletService();
  final LocalAuthentication auth = LocalAuthentication();
  double walletBalance = 0.00;
  bool _isBalanceHidden = true; // Default to hidden for privacy

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _toggleBalancePrivacy() async {
    // If it's already visible, just hide it (no auth needed to hide)
    if (!_isBalanceHidden) {
      setState(() => _isBalanceHidden = true);
      return;
    }

    // If hidden, use your standard authentication logic
    try {
      bool canCheck = await auth.canCheckBiometrics;
      bool isSupported = await auth.isDeviceSupported();

      if (canCheck || isSupported) {
        bool didAuth = await auth.authenticate(
          localizedReason: 'Please authenticate to reveal your wallet balance',
          // Following your pattern: biometricOnly: false allows PIN/Pattern backup
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );

        if (didAuth) {
          setState(() => _isBalanceHidden = false);
        }
      } else {
        // If device doesn't support biometrics, just reveal it
        setState(() => _isBalanceHidden = false);
      }
    } catch (e) {
      debugPrint("Security Error: $e");
      UIHelpers.showSnack(context, "Authentication failed", isError: true);
    }
  }

  Future<void> _loadWallet() async {
    final balance = await _walletService.getBalance();
    if (mounted) {
      setState(() => walletBalance = balance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      onDrawerChanged: (isOpen) => isOpen ? _loadWallet() : null,
      appBar: AppBar(title: Text(widget.title)),

      // --- REDESIGNED DRAWER ---
      drawer: Drawer(
        backgroundColor: const Color(0xFF161622),
        child: Column(
          children: [
            _buildDrawerHeader(theme),

            // Expanded allows the list to scroll if the screen is small
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 10),

                  // Nav Items
                  _buildDrawerItem(Icons.person_outline, 'User Profile', const Profile()),
                  _buildDrawerItem(Icons.add_card_outlined, 'Top Up Wallet', const WalletTopUp()),
                  _buildDrawerItem(Icons.account_balance_wallet_outlined, 'My Transactions', const FinancialHubPage()),

                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent, // Removes lines above/below when expanded
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      // tilePadding matches the horizontal padding of your other ListTiles (24)
                      tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: Icon(
                          Icons.calendar_month_outlined,
                          color: theme.primary.withOpacity(0.7),
                          size: 22
                      ),
                      title: const Text(
                          'Book a Class',
                          style: TextStyle(color: Colors.white70, fontSize: 15)
                      ),
                      trailing: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white38,
                          size: 20
                      ),
                      // This ensures sub-items are indented consistently
                      childrenPadding: const EdgeInsets.only(left: 12),
                      children: [
                        _buildDrawerItem(Icons.person, 'Private Class', const BookingPage()),
                        _buildDrawerItem(Icons.group, 'Public Class', const PublicBooking()),
                      ],
                    ),
                  ),

                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: Icon(
                          Icons.event_note_outlined,
                          color: theme.primary.withOpacity(0.7),
                          size: 22
                      ),
                      title: const Text(
                          'Booking History',
                          style: TextStyle(color: Colors.white70, fontSize: 15)
                      ),
                      trailing: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white38,
                          size: 20
                      ),
                      childrenPadding: const EdgeInsets.only(left: 12),
                      children: [
                        _buildDrawerItem(
                            Icons.history_toggle_off,
                            'Private History',
                            const BookingRecord()
                        ),
                        _buildDrawerItem(
                            Icons.groups_3_outlined,
                            'Public History',
                            const PublicRecord()
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(color: Colors.white10),
                  ),

                  _buildDrawerItem(Icons.admin_panel_settings_outlined, 'Admin Panel', const Admin()),

                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("v1.0.4", style: TextStyle(color: Colors.white24, fontSize: 12)),
            )
          ],
        ),
      ),

      body: _buildDashboardBody(theme),
    );
  }

  // Custom Drawer Header with Biometric Privacy Toggle
  Widget _buildDrawerHeader(ColorScheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 25),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        border: Border(bottom: BorderSide(color: theme.primary.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.primary.withOpacity(0.1),
                child: Icon(Icons.person, color: theme.primary, size: 30),
              ),
              const SizedBox(width: 15),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hello,", style: TextStyle(color: Colors.white54, fontSize: 14)),
                  Text("User One", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),

          // --- WALLET CHIP WITH PRIVACY TOGGLE ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: theme.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 18, color: theme.primary),
                    const SizedBox(width: 10),
                    const Text("Balance", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                // This section handles the tap and biometric reveal
                GestureDetector(
                  onTap: _toggleBalancePrivacy,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text(
                        _isBalanceHidden ? "RM ••••" : "RM ${walletBalance.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        _isBalanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 16,
                        color: theme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBody(ColorScheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dashboard Icon with Pulse Glow
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primary.withOpacity(0.05),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(0.1),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(Icons.grid_view_rounded, size: 80, color: theme.primary),
          ),
          const SizedBox(height: 30),
          const Text(
            'ABC Dashboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Swipe for Menu',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, Widget destination) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15)),
      onTap: () async {
        Navigator.pop(context); // Closes the drawer automatically
        await Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        _loadWallet(); // Refresh wallet in case they spent money
      },
    );
  }
}