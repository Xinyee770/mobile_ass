import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../Booking_UI/booking.dart';
import '../Booking_UI/public_booking.dart';
import '../Payment_UI/wallet_topup.dart';

class DashboardView extends StatefulWidget {
  final ColorScheme theme;
  final Map<String, dynamic>? weatherData;
  final bool isLoading;
  final String userName;
  final Function(Widget) onNavigate;

  const DashboardView({
    super.key,
    required this.theme,
    required this.userName,
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
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildWeatherBanner(),
        ),
        const SizedBox(height: 30),
        _buildQuickAccess(),
        const SizedBox(height: 35),
        _buildSectionTitle("Upcoming Classes"),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildUpcomingBox(),
        ),
        const SizedBox(height: 35),
        _buildSectionTitle("Explore Dance Courses"),
        const SizedBox(height: 15),
        _buildCarousel(),
        const SizedBox(height: 10),
        _buildDotIndicators(),
        const SizedBox(height: 40),
        _buildSectionTitle("Our Studio Location"),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildInteractiveMapWithDetails(),
        ),
        const SizedBox(height: 50),
      ],
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
    if (widget.isLoading) return const SizedBox(height: 110);
    String rawForecast = widget.weatherData?['morning_forecast'] ?? "Clear";
    bool isRainy = rawForecast.contains("Hujan") || rawForecast.contains("Ribut");
    bool isCloudy = rawForecast.contains("Berawan") || rawForecast.contains("Mendung");

    String bgUrl = isRainy
        ? "https://img.freepik.com/premium-photo/cartoon-illustration-stormy-sky-with-lightning-rain_14117-1146245.jpg"
        : (isCloudy
        ? "https://img.freepik.com/premium-vector/cute-cartoon-cloud-background-with-heart-shape-blue-sky_1199668-2244.jpg"
        : "https://static.vecteezy.com/system/resources/thumbnails/062/844/026/small/cute-bright-blue-cloud-in-the-sky-bottom-border-seamless-pattern-background-vector.jpg");

    return Container(
      width: double.infinity, height: 110,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(child: Image.network(bgUrl, fit: BoxFit.cover)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(isRainy ? Icons.thunderstorm_rounded : (isCloudy ? Icons.cloud_rounded : Icons.wb_sunny_rounded), color: Colors.white, size: 32),
                  const SizedBox(width: 15),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("It's ${isRainy ? 'Rainy' : (isCloudy ? 'Cloudy' : 'Clear')} • KL",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text("Perfect for studio practice!", style: TextStyle(color: Colors.white, fontSize: 12)),
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

  Widget _buildQuickAccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionItem(Icons.groups_rounded, "Public", Colors.purpleAccent, () => widget.onNavigate(const PublicBooking())),
          _buildActionItem(Icons.person_add_rounded, "Private", Colors.blueAccent, () => widget.onNavigate(const BookingPage())),
          _buildActionItem(Icons.account_balance_wallet_rounded, "Top-Up", Colors.orangeAccent, () => widget.onNavigate(const WalletTopUp())),
          _buildActionItem(Icons.qr_code_scanner_rounded, "Check-in", Colors.greenAccent, () => debugPrint("Open QR")),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.2))),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCarousel() {
    return SizedBox(
      height: 180,
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(25)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            Positioned.fill(child: Image.network(data['url']!, fit: BoxFit.cover)),
            Positioned.fill(child: Container(color: Colors.black38)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(data['title']!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(data['desc']!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
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
          height: 6, width: _currentPage == index ? 20 : 6,
          decoration: BoxDecoration(color: _currentPage == index ? widget.theme.primary : Colors.white24, borderRadius: BorderRadius.circular(3)),
        );
      }),
    );
  }
}