import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // IMPORT THIS
import '../services/wallet_service.dart';
import 'package:intl/intl.dart';

class WalletTransactionHistory extends StatefulWidget {
  const WalletTransactionHistory({super.key});

  @override
  State<WalletTransactionHistory> createState() => _WalletTransactionHistoryState();
}

class _WalletTransactionHistoryState extends State<WalletTransactionHistory> {
  final WalletService _walletService = WalletService();
  late Future<List<Map<String, dynamic>>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _walletService.getTransactionHistory();
  }

  Widget _buildSummaryHeader(List<Map<String, dynamic>> data, ColorScheme theme) {
    double totalCredits = 0;
    double totalDebits = 0;
    int creditCount = 0;
    int debitCount = 0;

    for (var item in data) {
      double amt = (item['amount'] ?? 0).toDouble().abs();
      if (item['transaction_type'] == 'credit') {
        totalCredits += amt;
        creditCount++;
      } else {
        totalDebits += amt;
        debitCount++;
      }
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), // Increased padding
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(28), // Softer corners
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(color: Colors.greenAccent, value: totalCredits == 0 ? 1 : totalCredits, title: '', radius: 18),
                  PieChartSectionData(color: Colors.redAccent, value: totalDebits == 0 ? 0.1 : totalDebits, title: '', radius: 14),
                ],
              ),
            ),
          ),
          const SizedBox(width: 25), // Increased gap
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatDetail("TOTAL CREDITS", "RM ${totalCredits.toStringAsFixed(2)}", Colors.greenAccent, Icons.add_chart),
                const SizedBox(height: 16),
                _buildStatDetail("TOTAL DEBITS", "RM ${totalDebits.toStringAsFixed(2)}", Colors.redAccent, Icons.analytics_outlined),
                const Divider(color: Colors.white10, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniCounter("$creditCount Credits", Colors.greenAccent),
                    _miniCounter("$debitCount Debits", Colors.redAccent),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

// Helper for the stat rows
  Widget _buildStatDetail(String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

// Helper for the count bubbles
  Widget _miniCounter(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    const Color bgDeep = Color(0xFF101018);
    const Color cardGrey = Color(0xFF1E1E2C);

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        title: const Text("Wallet Insights"),
        backgroundColor: bgDeep,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final transactions = snapshot.data ?? [];
          if (transactions.isEmpty) return _buildEmptyState();

          return Column(
            children: [
              // Integrated Pie Chart Header
              _buildSummaryHeader(transactions, theme),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("TRANSACTION LOG",
                      style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _buildTransactionItem(tx, theme, cardGrey);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, ColorScheme theme, Color cardColor) {
    DateTime date = DateTime.parse(tx['created_at']);
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    final bool isDebit = tx['transaction_type'] == 'debit';
    final double amount = (tx['amount'] as num).toDouble().abs();

    // NEW LOGIC: Determine the display title based on category
    String displayTitle = "";
    if (isDebit) {
      displayTitle = tx['description'] ?? "Course Payment";
    } else {
      // If it's a Credit, check if it's a refund or a normal top-up
      if (tx['category'] == 'refund') {
        displayTitle = "Refunded";
      } else {
        displayTitle = "Wallet Deposit";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isDebit ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
            child: Icon(
              // Change icon for refunds to make it distinct
              tx['category'] == 'refund' ? Icons.assignment_return_rounded :
              (isDebit ? Icons.arrow_outward_rounded : Icons.call_received_rounded),
              color: isDebit ? Colors.redAccent : Colors.greenAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      displayTitle, // Use the new dynamic title here
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)
                  ),
                  const SizedBox(height: 4),
                  // Show the description as a sub-text if it's a refund
                  if (tx['category'] == 'refund' && tx['description'] != null)
                    Text(tx['description'], style: const TextStyle(color: Colors.white38, fontSize: 10))
                  else
                    Text(formattedDate, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ),
          Text(
            "${isDebit ? "-" : "+"} RM ${amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: isDebit ? Colors.redAccent : Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 60, color: Colors.white10),
          SizedBox(height: 10),
          Text("No transactions yet", style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}