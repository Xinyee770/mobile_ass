import 'package:flutter/material.dart';
import '../Profile_UI/profile.dart';
import '../Booking_UI/booking.dart';
import '../Booking_UI/booking_record.dart';
import '../Booking_UI/public_booking.dart';
import '../Booking_UI/public_record.dart';
import '../Booking_UI/timetable.dart';
import '../Payment_UI/wallet_topup.dart';
import '../Payment_UI/FinancialHub_Page.dart';

class MainDrawer extends StatelessWidget {
  final ColorScheme theme;
  final String userName;
  final String avatarUrl;
  final double walletBalance;
  final bool isBalanceHidden;
  final VoidCallback onTogglePrivacy;
  final VoidCallback onLogout;
  final Function(Widget) onNavigate;

  const MainDrawer({
    super.key,
    required this.theme,
    required this.userName,
    required this.avatarUrl,
    required this.walletBalance,
    required this.isBalanceHidden,
    required this.onTogglePrivacy,
    required this.onLogout,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF161622),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 10),
                // Using a helper for cleaner code
                _tile(Icons.person_outline, 'User Profile', destination: 'profile'),
                _tile(Icons.add_card_outlined, 'Top Up Wallet', destination: 'topup'),
                _tile(Icons.account_balance_wallet_outlined, 'My Transactions', destination: 'finance'),
                _tile(Icons.calendar_view_day_outlined, 'My Timetable', destination: 'timetable'),

                _buildExpansionSection(
                  icon: Icons.calendar_month_outlined,
                  title: 'Book a Class',
                  children: [
                    _tile(Icons.person, 'Private Class', destination: 'booking'),
                    _tile(Icons.group, 'Public Class', destination: 'public_booking'),
                  ],
                ),

                _buildExpansionSection(
                  icon: Icons.event_note_outlined,
                  title: 'Booking History',
                  children: [
                    _tile(Icons.history_toggle_off, 'Private History', destination: 'record'),
                    _tile(Icons.groups_3_outlined, 'Public History', destination: 'public_record'),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Divider(color: Colors.white10),
                ),

                _tile(Icons.logout, 'Sign Out', isLogout: true),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("v1.0.4", style: TextStyle(color: Colors.white24, fontSize: 12)),
          )
        ],
      ),
    );
  }

  // --- DRAWER HEADER ---
  Widget _buildHeader() {
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
                radius: 30,
                backgroundColor: Colors.grey[800],
                backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Hello,", style: TextStyle(color: Colors.white54, fontSize: 14)),
                  Text(userName, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          _buildBalanceChip(),
        ],
      ),
    );
  }

  Widget _buildBalanceChip() {
    return Container(
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
          GestureDetector(
            onTap: onTogglePrivacy,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  isBalanceHidden ? "RM ••••" : "RM ${walletBalance.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 10),
                Icon(
                  isBalanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 16,
                  color: theme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER FOR LIST TILES ---
  // To avoid circular dependency, we pass strings to a map in home.dart or just handle navigation logic here
  Widget _tile(IconData icon, String label, {String? destination, bool isLogout = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: theme.primary.withOpacity(0.7), size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15)),
      onTap: () {
        if (isLogout) {
          onLogout();
        } else if (destination != null) {
          // This calls the navigation logic back in home.dart
          onNavigate(_getWidgetFromKey(destination));
        }
      },
    );
  }

  Widget _buildExpansionSection({required IconData icon, required String title, required List<Widget> children}) {
    return Theme(
      data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(icon, color: theme.primary.withOpacity(0.7), size: 22),
        title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 20),
        childrenPadding: const EdgeInsets.only(left: 12),
        children: children,
      ),
    );
  }

  // A simple mapper to keep navigation clean
  Widget _getWidgetFromKey(String key) {
    switch (key) {
      case 'profile': return const Profile();
      case 'topup': return const WalletTopUp();
      case 'finance': return const FinancialHubPage();
      case 'booking': return const BookingPage();
      case 'public_booking': return const PublicBooking();
      case 'record': return const BookingRecord();
      case 'public_record': return const PublicRecord();
      case 'timetable': return const TimetablePage();
      default: return const SizedBox();
    }
  }
}