import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Authentication_UI/login.dart';
import 'package:local_auth/local_auth.dart';
import 'utils/ui_helpers.dart';
import 'widgets/main_drawer.dart';
import 'widgets/dashboard_view.dart';
import 'services/wallet_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    const Color brandPurple = Color(0xFF9D59FF); // Electric Purple
    const Color bgDeep = Color(0xFF0F0F16);      // Deep dark background
    const Color cardGrey = Color(0xFF1E1E2C);    // Charcoal surface color

    return MaterialApp(
      title: 'Dancing Monkey Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
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
      home: const MyHomePage(title: 'Dancing Monkey Academy'),
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
  bool _isBalanceHidden = true;
  int passes =0;
  String userName = "User";
  String avatarUrl = "";
  dynamic _malaysiaWeather;
  bool _isLoadingWeather = true;


  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _loadWallet();
    _loadUserProfile();
    _fetchMETMalaysiaWeather();
  }

  Future<void> _toggleBalancePrivacy() async {
    // If it's already visible, just hide it (no auth needed to hide)
    if (!_isBalanceHidden) {
      setState(() => _isBalanceHidden = true);
      return;
    }

    try {
      bool canCheck = await auth.canCheckBiometrics;
      bool isSupported = await auth.isDeviceSupported();

      if (canCheck || isSupported) {
        bool didAuth = await auth.authenticate(
          localizedReason: 'Please authenticate to reveal your wallet balance',
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );

        if (didAuth) {
          setState(() => _isBalanceHidden = false);
        }
      } else {
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('cached_balance', balance);
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
          avatarUrl = data['avatar_url'] ?? "";
          passes = data['passes'] ?? 0;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_name', userName);
        await prefs.setString('cached_avatar', avatarUrl);
        await prefs.setInt('cached_passes', passes);
      }
    } catch (e) {
      debugPrint("Error loading profile on Home: $e");
    }
  }

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

  Future<void> _fetchMETMalaysiaWeather() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.data.gov.my/weather/forecast?contains=St009@location__location_id'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {

          setState(() {
            _malaysiaWeather = data;
            _isLoadingWeather = false;
          });
        }
      }
    } catch (e) {
      debugPrint("DEBUG ERROR: $e");
      setState(() => _isLoadingWeather = false);
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
        avatarUrl: avatarUrl,
        walletBalance: walletBalance,
        isBalanceHidden: _isBalanceHidden,
        onTogglePrivacy: _toggleBalancePrivacy,
        onLogout: _confirmLogout,
        onNavigate: (Widget page) async {
          Navigator.pop(context);
          await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          _loadWallet();
          _loadUserProfile();
        },
      ),
      body: DashboardView(
        theme: theme,
        userName: userName,
        avatarUrl: avatarUrl,
        passes: passes,
        weatherData: _malaysiaWeather,
        isLoading: _isLoadingWeather,
        onNavigate: _handleNavigation,
      ),
    );
  }
  void _handleNavigation(Widget page) async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    _loadWallet();
  }


  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        userName = prefs.getString('cached_name') ?? "User";
        walletBalance = prefs.getDouble('cached_balance') ?? 0.00;
      });
    }
  }
}