import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Authentication_UI/login.dart';
import 'package:local_auth/local_auth.dart';
import 'utils/ui_helpers.dart';
import 'Admin_UI/admin.dart';
import 'widgets/main_drawer.dart';
import 'widgets/dashboard_view.dart';
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
  String userName = "User"; // Default name = user if no user login

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadUserProfile();
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

  Future<void> _loadUserProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          userName = data['name'] ?? "User";
        });
      }
    } catch (e) {
      debugPrint("Profile load error: $e");
    }
  }

  // Logout confirmation popout
  Future<void> _confirmLogout() async {
    final supabase = Supabase.instance.client;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
          content: const Text(
            "Are you sure you want to sign out?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Sign Out",
                style: TextStyle(color: Color(0xFF9D59FF)),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      onDrawerChanged: (isOpen) => isOpen ? _loadWallet() : null,
      appBar: AppBar(title: Text(widget.title)),

      drawer: MainDrawer(
        theme: theme,
        userName: userName,
        walletBalance: walletBalance,
        isBalanceHidden: _isBalanceHidden,
        onTogglePrivacy: _toggleBalancePrivacy,
        onLogout: _confirmLogout,
        onNavigate: (Widget page) async {
          Navigator.pop(context); // Close the drawer
          await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          _loadWallet(); // Refresh wallet if they top up
        },
      ),
      body: DashboardView(theme: theme),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hello,", style: TextStyle(color: Colors.white54, fontSize: 14)),
                  Text(userName, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
}