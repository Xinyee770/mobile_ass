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

  // --- NEW: PIE CHART SECTION ---
  Widget _buildSummaryHeader(List<Map<String, dynamic>> data, ColorScheme theme) {
    double totalIn = 0;
    for (var item in data) {
      totalIn += (item['amount'] ?? 0).toDouble();
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      height: 180, // Fixed height for the chart area
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // 1. THE PIE CHART
          Expanded(
            flex: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    color: theme.primary,
                    value: totalIn,
                    title: '', // Hide text inside pie
                    radius: 12,
                  ),
                  PieChartSectionData(
                    color: Colors.white10,
                    value: 100, // Background gray to show "potential"
                    title: '',
                    radius: 10,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 20),

          // 2. THE TOTALS DATA
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total Savings",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 4),
                Text("RM ${totalIn.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.trending_up, color: theme.primary, size: 16),
                    const SizedBox(width: 5),
                    Text("${data.length} Top-ups",
                        style: TextStyle(color: theme.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
    // Parse the date
    DateTime date = DateTime.parse(tx['created_at']);
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.primary.withOpacity(0.1),
            child: Icon(Icons.add_rounded, color: theme.primary),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Wallet Top-up",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(formattedDate,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Text(
            "+ RM ${tx['amount'].toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
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