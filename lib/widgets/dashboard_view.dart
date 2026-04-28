import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_ass/Booking_UI/booking.dart';
import 'package:mobile_ass/Booking_UI/public_booking.dart';
import 'package:mobile_ass/Payment_UI/wallet_topup.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Profile_UI/profile.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class DashboardView extends StatefulWidget {
  final ColorScheme theme;
  final dynamic weatherData;
  final String avatarUrl;
  final int passes;
  final bool isLoading;
  final String userName;
  final Function(Widget) onNavigate;

  const DashboardView({
    super.key,
    required this.theme,
    required this.userName,
    required this.passes,
    required this.avatarUrl,
    required this.onNavigate,
    this.weatherData,
    this.isLoading = false,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  // --- Controllers & Timers ---
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _bannerTimer;
  Timer? _countdownTimer;

  // --- Countdown State ---
  Map<String, dynamic>? _nextBooking;
  Duration _timeLeft = Duration.zero;

  // --- Studio Data ---
  static const LatLng _studioLocation = LatLng(3.2039, 101.7145);
  final String studioName = "ABC Dance Studio - Setapak";
  final String studioAddress = "38-06, Vista Danau Kota, Setapak, 53300 Kuala Lumpur";

  final List<Map<String, String>> _bannerData = [
    {
      "title": "Beginner K-Pop",
      "desc": "Learn the latest idol choreography",
      "url": "https://images.unsplash.com/photo-1547153760-18fc86324498?q=80&w=600&auto=format",
    },
    {
      "title": "Urban Hip-Hop",
      "desc": "Master your grooves and power moves",
      "url": "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?q=80&w=600&auto=format",
    },
    {
      "title": "Lyrical Jazz",
      "desc": "Express yourself through fluid motion",
      "url": "https://images.unsplash.com/photo-1508807526345-15e9b5f4eaff?q=80&w=600&auto=format",
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoSlider();
    _fetchNextBooking();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _countdownTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // --- LOGIC: Fetch Next Class from Supabase ---
  Future<void> _fetchNextBooking() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final response = await Supabase.instance.client
          .from('booking')
          .select('*, courses(course_name)')
          .eq('user_id', user.id)
          .gte('booking_date', today)
          .order('booking_date', ascending: true)
          .order('start_time', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() => _nextBooking = response);
        _startCountdown();
      }
    } catch (e) {
      debugPrint("Dashboard Countdown Fetch Error: $e");
    }
  }

  // --- LOGIC: Timer Ticker ---
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextBooking == null) return;

      try {
        final DateTime classDate = DateTime.parse(_nextBooking!['booking_date']);
        final String rawTime = _nextBooking!['start_time'].toString();

        final List<String> timeParts = rawTime.split(':');
        final int hour = int.parse(timeParts[0]);
        final int minute = int.parse(timeParts[1]);

        final DateTime classDateTime = DateTime(
          classDate.year, classDate.month, classDate.day, hour, minute,
        );

        final now = DateTime.now();
        final difference = classDateTime.difference(now);

        if (difference.isNegative) {
          _countdownTimer?.cancel();
          _fetchNextBooking();
        } else {
          if (mounted) {
            setState(() => _timeLeft = difference);
          }
        }
      } catch (e) {
        _countdownTimer?.cancel();
      }
    });
  }

  void _startAutoSlider() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients) {
        _currentPage = (_currentPage + 1) % _bannerData.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutQuart,
        );

        // This forces the UI to re-check the clock for the weather banner every 4 seconds
        if (mounted) setState(() {});
      }
    });
  }

  // --- UI: Show Info Dialog ---
  void _showBookingDetails(BuildContext context, Map<String, dynamic> booking) {
    final String courseName = booking['courses']?['course_name'] ?? "Dance Class";
    final String date = booking['booking_date'] ?? "N/A";
    final String time = booking['start_time'] ?? "N/A";
    final String status = booking['booking_status'] ?? "Confirmed";

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 25),
            const Text("Booking Details",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _detailRow(Icons.auto_awesome, "Course", courseName),
            _detailRow(Icons.calendar_month, "Date", date),
            _detailRow(Icons.access_time_filled, "Time", time),
            _detailRow(Icons.verified_user, "Status", status),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: widget.theme.primary, size: 24),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: widget.theme.primary,
      backgroundColor: const Color(0xFF1E1E2C),
      onRefresh: () async {
        // Refresh your data here
        await _fetchNextBooking();
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // --- HEADER SECTION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => widget.onNavigate(const Profile()),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: widget.avatarUrl.isNotEmpty
                        ? NetworkImage(widget.avatarUrl)
                        : null,
                    child: widget.avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome Back,",
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // PASSES CHIP
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.theme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.theme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.confirmation_number_rounded, size: 14, color: widget.theme.primary),
                      const SizedBox(width: 6),
                      Text(
                        "${widget.passes} Passes",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 1. Weather Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildWeatherBanner(),
          ),

          const SizedBox(height: 30),

          // 2. Quick Access
          _buildQuickAccess(),

          const SizedBox(height: 35),

          // 3. Upcoming Classes (Friend's Timer Logic)
          _buildSectionTitle("Upcoming Classes"),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildUpcomingBox(), // Corrected to friend's function name
          ),

          const SizedBox(height: 35),

          // 4. Carousel
          _buildSectionTitle("Explore Dance Courses"),
          const SizedBox(height: 15),
          _buildCarousel(),
          const SizedBox(height: 10),
          _buildDotIndicators(),

          const SizedBox(height: 40),

          // 5. Studio Locator (Friend's Map Logic)
          _buildSectionTitle("Our Studios"),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildInteractiveMapWithDetails(), // Corrected to friend's function name
          ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. PUBLIC CLASS
          _buildActionItem(
            Icons.groups_rounded,
            "Public",
            Colors.purpleAccent,
                () => widget.onNavigate(const PublicBooking()), // Direct Link
          ),

          // 2. PRIVATE CLASS
          _buildActionItem(
            Icons.person_add_rounded,
            "Private",
            Colors.blueAccent,
                () => widget.onNavigate(const BookingPage()), // Direct Link
          ),

          // 3. WALLET TOP UP
          _buildActionItem(
            Icons.account_balance_wallet_rounded,
            "Top-Up",
            Colors.orangeAccent,
                () => widget.onNavigate(const WalletTopUp()), // Direct Link
          ),

          // 4. CHECK-IN (Placeholder - adjust if you have a QR page)
          _buildActionItem(
            Icons.qr_code_scanner_rounded,
            "Check-in",
            Colors.greenAccent,
                () => _showCheckInQR(context),
          ),
        ],
      ),
    );
  }

  void _showCheckInQR(BuildContext context) {
    // We grab the ID from Supabase directly
    final userId = Supabase.instance.client.auth.currentUser?.id ?? "No ID";

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Scan to Check-in", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: QrImageView(data: userId, size: 200), // Uses the same QR library
            ),
            const SizedBox(height: 20),
            Text("ID: $userId", style: const TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // Update helper to accept an onTap function
  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Handy helper to keep code clean
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildUpcomingBox() {
    if (_nextBooking == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined, color: Colors.white.withOpacity(0.2), size: 32),
            const SizedBox(height: 12),
            Text("No classes booked yet", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
          ],
        ),
      );
    }

    final String courseName = _nextBooking!['courses']?['course_name'] ?? "Class";
    String hours = _timeLeft.inHours.toString().padLeft(2, '0');
    String minutes = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.theme.primary.withOpacity(0.9), const Color(0xFF6C42F5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: widget.theme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("NEXT CLASS STARTS IN",
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(courseName.toUpperCase(),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showBookingDetails(context, _nextBooking!),
                icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _timeUnit(hours, "HRS"),
              _timeDivider(),
              _timeUnit(minutes, "MIN"),
              _timeDivider(),
              _timeUnit(seconds, "SEC"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeUnit(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _timeDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 12, right: 12, bottom: 15),
      child: Text(":", style: TextStyle(color: Colors.white38, fontSize: 28, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInteractiveMapWithDetails() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200, width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(target: _studioLocation, zoom: 15),
                markers: {const Marker(markerId: MarkerId('studio'), position: _studioLocation)},
                mapType: MapType.normal,
                zoomControlsEnabled: false,
                mapToolbarEnabled: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: widget.theme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                  child: Icon(Icons.location_on_rounded, color: widget.theme.primary, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studioName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(studioAddress, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4)),
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

  Widget _buildWeatherBanner() {
    if (widget.isLoading || widget.weatherData == null) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }

    // 1. Get today's date in YYYY-MM-DD format
    // This produces "2026-04-28"
    String todayDate = DateTime.now().toString().split(' ')[0];

    dynamic todayData;

    // 2. SCAN the list to find the item where 'date' matches '2026-04-28'
    if (widget.weatherData is List) {
      List<dynamic> weatherList = widget.weatherData;
      todayData = weatherList.firstWhere(
            (element) => element['date'] == todayDate,
        orElse: () => weatherList[0], // Fallback to first item if not found
      );
    } else {
      todayData = widget.weatherData;
    }


    int hour = DateTime.now().hour;
    bool isNight = hour >= 18 || hour < 6;

    // 3. Get the correct forecast slot
    String rawForecast = "";
    if (hour < 12) {
      rawForecast = todayData['morning_forecast']?.toString().toLowerCase() ?? "";
    } else if (hour < 18) {
      rawForecast = todayData['afternoon_forecast']?.toString().toLowerCase() ?? "";
    } else {
      // Because we found 2026-04-28, this will now correctly be "ribut petir..."
      rawForecast = todayData['night_forecast']?.toString().toLowerCase() ?? "";
    }

    // 4. Keyword check
    bool isRainy = (rawForecast.contains("hujan") || rawForecast.contains("ribut"))
        && !rawForecast.contains("tiada");
    bool isCloudy = rawForecast.contains("berawan") || rawForecast.contains("mendung");

    // 5. Pick UI elements
    String displayTitle = isRainy ? "Stormy" : (isCloudy ? "Cloudy" : "Clear Skies");
    String subtitleText = isRainy
        ? "Lightning outside! Stay safe."
        : (isNight ? "Great night for a late session!" : "Perfect day for practice!");

    // Background logic
    String bgUrl = isRainy
        ? (isNight
        ? "https://cdn.suwalls.com/wallpapers/fantasy/rainy-city-at-night-16438-1920x1080.jpg"
        : "https://images.stockcake.com/public/6/5/8/658984ea-3367-44a5-9525-4d0abdfec6a6_large/rainy-pixel-city-stockcake.jpg")
        : (isNight
        ? "https://wallpapers.com/images/hd/pastel-sky-on-a-beautiful-night-i9neq2ed7blcu74r.jpg"
        : (isCloudy
        ? "https://img.freepik.com/free-vector/modern-cloudy-skyscape-background-with-papercut-effect_1017-50492.jpg"
        : "https://static.vecteezy.com/system/resources/thumbnails/062/844/026/small/cute-bright-blue-cloud-in-the-sky-bottom-border-seamless-pattern-background-vector.jpg"));

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(child: Image.network(bgUrl, fit: BoxFit.cover)),
            Positioned.fill(child: Container(color: Colors.black.withOpacity(isNight ? 0.4 : 0.1))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  Icon(
                    isRainy ? Icons.thunderstorm_rounded : (isNight ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded),
                    color: Colors.white,
                    size: 40,
                    shadows: const [Shadow(blurRadius: 15, color: Colors.black)],
                  ),
                  const SizedBox(width: 20),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("It's $displayTitle • KL", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                      Text(subtitleText, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return SizedBox(
      height: 180, // Slightly taller for more impact
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) => setState(() => _currentPage = page),
        itemCount: _bannerData.length,
        itemBuilder: (context, index) => _buildCarouselItem(_bannerData[index]),
      ),
    );
  }

  Widget _buildCarouselItem(Map<String, String> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(data['url']!, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    data['title']!,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data['desc']!,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_bannerData.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: _currentPage == index ? 20 : 6,
          decoration: BoxDecoration(
            color: _currentPage == index ? widget.theme.primary : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}