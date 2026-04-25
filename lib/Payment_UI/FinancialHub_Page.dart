import 'package:flutter/material.dart';
import 'wallet_history.dart';
import 'payment_read.dart';


class FinancialHubPage extends StatefulWidget {
  const FinancialHubPage({super.key});

  @override
  State<FinancialHubPage> createState() => _FinancialHubPageState();
}

class _FinancialHubPageState extends State<FinancialHubPage> {
  int _currentIndex = 0;

  // The two pages you are combining
  final List<Widget> _pages = [
    const PaymentHistoryPage(), // Your existing page
    const WalletTransactionHistory(),  // Your wallet specific page
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF1A1D29), // surfaceDark
          selectedItemColor: const Color(0xFF9D59FF), // primaryPurple
          unselectedItemColor: const Color(0xFF9496A1), // textMuted
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Payments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Wallet',
            ),
          ],
        ),
      ),
    );
  }
}