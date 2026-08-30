import 'package:flutter/material.dart';
import '../admin_theme.dart';

class SystemConfigurationScreen extends StatelessWidget {
  final String mode;
  const SystemConfigurationScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mode.contains("Payment")) _buildPaymentConfig()
          else if (mode.contains("SMS")) _buildSMSConfig()
          else if (mode.contains("Bank")) _buildBankConfig()
          else _buildGenericList(),
        ],
      ),
    );
  }

  Widget _buildPaymentConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildConfigCard("Cash Payment", "Active", Icons.payments_outlined, AdminTheme.emeraldGreen),
        _buildConfigCard("Fonepay (QR)", "Active", Icons.qr_code_scanner, AdminTheme.royalBlue),
        _buildConfigCard("Bank Card", "Pending", Icons.credit_card_outlined, Colors.orange),
      ],
    );
  }

  Widget _buildConfigCard(String title, String status, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
      child: Row(
        children: [
          Icon(icon, color: AdminTheme.darkNavy, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildSMSConfig() {
    return Column(
      children: [
        const Icon(Icons.sms_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text("SMS Gateway Integration", style: TextStyle(fontWeight: FontWeight.bold)),
        const Text("Connect your SMS provider API to send automated alerts.", style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: () {}, child: const Text("CONFIGURE API")),
      ],
    );
  }

  Widget _buildBankConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Connected Banks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
          child: const Column(
            children: [
              ListTile(leading: Icon(Icons.account_balance), title: Text("Nabil Bank Ltd."), subtitle: Text("Acc: ****9820")),
              Divider(),
              ListTile(leading: Icon(Icons.account_balance), title: Text("Global IME Bank"), subtitle: Text("Acc: ****1105")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenericList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...List.generate(3, (i) => Card(child: ListTile(title: Text("Option ${i+1}"), trailing: const Icon(Icons.chevron_right)))),
      ],
    );
  }
}
