import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_ass/Booking_UI/booking.dart';
import 'package:mobile_ass/Booking_UI/public_booking.dart';
import 'package:mobile_ass/Payment_UI/wallet_topup.dart';

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
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

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
  }

  void _startAutoSlider() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients) {
        if (_currentPage < _bannerData.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutQuart,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        // 1. Weather Banner (Top)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildWeatherBanner(),
        ),

        const SizedBox(height: 30),

        // 2. Quick Access (Fastest Utility)
        _buildQuickAccess(),

        const SizedBox(height: 35),

        // 3. Upcoming Classes (Personal Priority)
        _buildSectionTitle("Upcoming Classes"),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildUpcomingClassPlaceholder(),
        ),

        const SizedBox(height: 35),

        // 4. Explore Courses (Discovery)
        _buildSectionTitle("Explore Dance Courses"),
        const SizedBox(height: 15),
        _buildCarousel(),
        const SizedBox(height: 10),
        _buildDotIndicators(),

        const SizedBox(height: 40),

        // 5. STUDIO LOCATOR SECTION
        _buildSectionTitle("Our Studios"),
        const SizedBox(height: 15),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildStudioPlaceholder(),
        ),

        const SizedBox(height: 50), // Final bottom breathing room
      ],
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
                () => print("Open QR Scanner"),
          ),
        ],
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

  // --- ADD THIS WIDGET FOR THE LOGIC AREA ---
  Widget _buildUpcomingClassPlaceholder() {
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
          Icon(
            Icons.calendar_today_outlined,
            color: Colors.white.withOpacity(0.2),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            "No classes booked yet",
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          // Reminder for logic implementation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.theme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "ADD BOOKING LOGIC HERE",
              style: TextStyle(
                color: widget.theme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherBanner() {
    if (widget.isLoading) return const SizedBox(height: 100);

    // --- TESTING LOGIC: CHANGE THIS STRING TO TEST ---
    // Change to "Hujan" to see Rain, "Berawan" to see Cloudy, or "Clear" for Sunny
    String rawForecast = widget.weatherData?['morning_forecast'] ?? "Clear";

    bool isRainy = rawForecast.contains("Hujan") || rawForecast.contains("Ribut");
    bool isCloudy = rawForecast.contains("Berawan") || rawForecast.contains("Mendung");

    String bgUrl = isRainy
        ? "https://img.freepik.com/premium-photo/cartoon-illustration-stormy-sky-with-lightning-rain_14117-1146245.jpg"
        : (isCloudy
        ? "https://img.freepik.com/premium-vector/cute-cartoon-cloud-background-with-heart-shape-blue-sky_1199668-2244.jpg"
        : "https://static.vecteezy.com/system/resources/thumbnails/062/844/026/small/cute-bright-blue-cloud-in-the-sky-bottom-border-seamless-pattern-background-vector.jpg");

    String displayTitle = isRainy ? "Rainy" : (isCloudy ? "Cloudy" : "Clear Skies");

    return Container(
      width: double.infinity,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 1. Background Image
            Positioned.fill(
              child: Image.network(bgUrl, fit: BoxFit.cover),
            ),

            // 2. Content Centered
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center, // Vertically centered
                children: [
                  Icon(
                    isRainy ? Icons.thunderstorm_rounded : (isCloudy ? Icons.cloud_rounded : Icons.wb_sunny_rounded),
                    color: Colors.white,
                    size: 32,
                    shadows: const [Shadow(blurRadius: 10, color: Colors.black45)], // Keeps text visible
                  ),
                  const SizedBox(width: 15),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Vertically centered
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "It's $displayTitle • KL",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
                        ),
                      ),
                      const Text(
                        "Perfect for studio practice!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
                        ),
                      ),
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

  Widget _buildStudioPlaceholder() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulated Map Background
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              image: const DecorationImage(
                image: NetworkImage("https://miro.medium.com/v2/resize:fit:1400/1*q69_S-O5CisS36S9YxX_6A.png"), // A static map placeholder
                fit: BoxFit.cover,
                opacity: 0.5,
              ),
            ),
            child: Center(
              child: Icon(Icons.location_on_rounded, color: widget.theme.primary, size: 40),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "ABC Dance Studio - KL",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Bukit Bintang, Kuala Lumpur",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => print("Logic: Open Google Maps"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.theme.primary.withOpacity(0.1),
                    foregroundColor: widget.theme.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Directions", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Technical Note for Friend
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: widget.theme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Text(
              "GOOGLE MAPS API PLACEHOLDER",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.theme.primary.withOpacity(0.5),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}