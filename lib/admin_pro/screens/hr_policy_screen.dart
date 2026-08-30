import 'package:flutter/material.dart';
import '../admin_theme.dart';

class HRPolicyScreen extends StatelessWidget {
  final String mode;
  const HRPolicyScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mode.contains("Leave")) _buildLeaveView()
          else if (mode.contains("Loan")) _buildLoanView()
          else if (mode.contains("Award")) _buildAwardView()
          else _buildPolicyListView(),
        ],
      ),
    );
  }

  Widget _buildLeaveView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...List.generate(3, (index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.beach_access_outlined, color: Colors.orange),
            title: Text(index == 0 ? "Annual Leave" : "Sick Leave"),
            subtitle: const Text("Balance: 12 Days"),
            trailing: const Icon(Icons.chevron_right),
          ),
        )),
      ],
    );
  }

  Widget _buildLoanView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Loan Applications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AdminTheme.royalBlue, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text("Total Interest Free Loans", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("NPR 120,400 Disbursed", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAwardView() {
    return Column(
      children: [
        const Center(child: Icon(Icons.emoji_events_outlined, size: 64, color: Colors.amber)),
        const SizedBox(height: 24),
        const Text("Staff Recognition", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const Text("Reward your top performers to boost morale.", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: () {}, child: const Text("ANNOUNCE AWARD")),
      ],
    );
  }

  Widget _buildPolicyListView() {
    return Column(
      children: [
        Text(mode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        const Center(child: Text("Policy documents and internal rules are listed here.", style: TextStyle(color: Colors.grey))),
      ],
    );
  }
}
