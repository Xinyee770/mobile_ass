import 'package:flutter/material.dart';

class DashboardView extends StatelessWidget {
  final ColorScheme theme;
  final Map<String, dynamic>? weatherData;
  final bool isLoading;

  const DashboardView({
    super.key,
    required this.theme,
    this.weatherData,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView( // Added to prevent overflow if the screen is small
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. YOUR MAIN ICON
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
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 10),

            // 2. SWIPE HINT
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

            const SizedBox(height: 40), // Space before the weather card

            // 3. THE NEW WEATHER SECTION
            if (isLoading)
              const CircularProgressIndicator()
            else if (weatherData != null)
              _buildWeatherCard()
            else
              const Text(
                "Weather currently unavailable",
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    // Extracting data from the Malaysia API structure
    final forecast = weatherData!['morning_forecast'] ?? "No Forecast";
    final location = weatherData!['location']?['location_name'] ?? "Kuala Lumpur";

    // Quick Logic for Icon and Advice
    bool isRainy = forecast.contains("Hujan") || forecast.contains("Ribut");

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C), // Matches your cardGrey
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          // Weather Icon
          Icon(
            isRainy ? Icons.umbrella_rounded : Icons.wb_sunny_rounded,
            color: theme.primary,
            size: 40,
          ),
          const SizedBox(width: 20),

          // Weather Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "MET MALAYSIA • $location",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  forecast,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isRainy
                      ? "Bring an umbrella to the studio!"
                      : "Clear skies for dance class!",
                  style: TextStyle(
                      color: theme.primary.withOpacity(0.9),
                      fontSize: 13,
                      fontStyle: FontStyle.italic
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