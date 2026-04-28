import 'package:flutter/material.dart';

class DashboardView extends StatelessWidget {
  // We pass the ColorScheme from the parent so the colors stay consistent
  final ColorScheme theme;

  const DashboardView({
    super.key,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
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
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1
            ),
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

          // --- THIS IS WHERE WE WILL ADD THE WEATHER LATER ---
          // _buildWeatherSection(),
        ],
      ),
    );
  }
}