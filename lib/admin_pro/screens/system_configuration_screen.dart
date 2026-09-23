import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin_theme.dart';
import '../../services/language_service.dart';

class SystemConfigurationScreen extends StatefulWidget {
  final String mode;
  const SystemConfigurationScreen({super.key, required this.mode});

  @override
  State<SystemConfigurationScreen> createState() => _SystemConfigurationScreenState();
}

class _SystemConfigurationScreenState extends State<SystemConfigurationScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _configState = {
    "restaurant_name": "Chiyalaa Global Hub",
    "restaurant_id": "CHY-PRO-9901",
    "location": "Main Road, Butwal, Nepal",
    "contact_email": "admin@chiyalaa.com",
    "contact_phone": "+977-98XXXXXXXX",
    "currency": "NPR",
    "timezone": "Asia/Kathmandu",
    "vat_percentage": 13.0,
    "service_charge": 10.0,
    "sms_sender_id": "CHIYALAA",
    "subscription_plan": "ENTERPRISE ELITE",
  };

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString('system_config_data');
    if (saved != null) {
      setState(() {
        _configState = json.decode(saved);
        _populateControllers();
        _isLoading = false;
      });
    } else {
      _populateControllers();
      setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    _nameController.text = _configState['restaurant_name'] ?? "";
    _emailController.text = _configState['contact_email'] ?? "";
    _phoneController.text = _configState['contact_phone'] ?? "";
    _addressController.text = _configState['location'] ?? "";
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    
    _configState['restaurant_name'] = _nameController.text;
    _configState['contact_email'] = _emailController.text;
    _configState['contact_phone'] = _phoneController.text;
    _configState['location'] = _addressController.text;

    await prefs.setString('system_config_data', json.encode(_configState));
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Configurations synchronized successfully!"), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _buildStickyHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _buildContentByMode(),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.mode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
              const Text("Global system environment and business rules.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _saveConfig,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text("SYNC CHANGES"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.royalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentByMode() {
    switch (widget.mode) {
      case "Application Setting":
        return _buildApplicationSetting();
      case "Payment Method List":
      case "Payment Setup":
        return _buildPaymentConfig();
      case "SMS Configuration":
      case "SMS Template":
        return _buildSMSConfig();
      case "Bank List":
      case "Bank Transaction":
        return _buildBankConfig();
      case "Language":
        return _buildLanguageSettings();
      default:
        return _buildGenericConfig();
    }
  }

  Widget _buildApplicationSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("RESTAURANT IDENTITY"),
        const SizedBox(height: 24),
        _buildConfigInput("Restaurant Name", _nameController, Icons.restaurant),
        const SizedBox(height: 16),
        _buildConfigInput("Business Address", _addressController, Icons.location_on_outlined),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildConfigInput("Admin Email", _emailController, Icons.email_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _buildConfigInput("Support Phone", _phoneController, Icons.phone_android)),
          ],
        ),
        const SizedBox(height: 48),
        _buildSectionTitle("FINANCIAL ENVIRONMENT"),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildReadonlyCard("Currency", _configState['currency'], Icons.payments_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _buildReadonlyCard("VAT Percentage", "${_configState['vat_percentage']}%", Icons.percent)),
            const SizedBox(width: 16),
            Expanded(child: _buildReadonlyCard("Service Charge", "${_configState['service_charge']}%", Icons.room_service_outlined)),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("ACTIVE PAYMENT METHODS"),
        const SizedBox(height: 24),
        _buildConfigCard("Cash Payment", "Active", Icons.payments_outlined, AdminTheme.emeraldGreen),
        _buildConfigCard("Fonepay (QR)", "Active", Icons.qr_code_scanner, AdminTheme.royalBlue),
        _buildConfigCard("Bank Card Terminal", "Offline", Icons.credit_card_outlined, Colors.red),
        _buildConfigCard("eSewa Wallet", "Active", Icons.account_balance_wallet_outlined, Colors.green),
      ],
    );
  }

  Widget _buildSMSConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("GATEWAY STATUS"),
        const SizedBox(height: 24),
        _buildConfigCard("Sender ID: ${_configState['sms_sender_id']}", "Configured", Icons.sms, AdminTheme.royalBlue),
        const SizedBox(height: 48),
        _buildSectionTitle("MESSAGE TEMPLATES"),
        const SizedBox(height: 16),
        _buildTemplateTile("Reservation Confirmed", "Dear [Name], your table is booked..."),
        _buildTemplateTile("Order Ready", "Your order #[ID] is ready for pickup!"),
        _buildTemplateTile("Payment Received", "Thank you! We received your payment..."),
      ],
    );
  }

  Widget _buildBankConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("CONNECTED CORPORATE ACCOUNTS"),
        const SizedBox(height: 24),
        _buildConfigCard("Global IME Bank", "Verified", Icons.account_balance, Colors.indigo),
        _buildConfigCard("NIC Asia Bank", "Active", Icons.account_balance, Colors.red),
        _buildConfigCard("Nabil Bank Ltd", "Pending", Icons.account_balance, Colors.orange),
      ],
    );
  }

  Widget _buildLanguageSettings() {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService().currentLanguageCode,
      builder: (context, currentCode, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("SYSTEM LANGUAGES"),
            const SizedBox(height: 24),
            ...LanguageService().languages.value.map((l) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: l.code == currentCode ? AdminTheme.royalBlue : Colors.grey.shade100, width: 2),
                boxShadow: AdminTheme.softShadow,
              ),
              child: ListTile(
                onTap: () => LanguageService().setLanguage(l.code),
                leading: CircleAvatar(
                  backgroundColor: l.code == currentCode ? AdminTheme.royalBlue : Colors.grey.shade100,
                  child: Text(l.code.toUpperCase(), style: TextStyle(color: l.code == currentCode ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l.nativeName, style: const TextStyle(fontSize: 12)),
                trailing: l.code == currentCode ? const Icon(Icons.check_circle, color: AdminTheme.royalBlue) : null,
              ),
            )),
          ],
        );
      }
    );
  }

  Widget _buildGenericConfig() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tune, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text("Configuration for ${widget.mode} coming soon.", style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2));
  }

  Widget _buildConfigInput(String label, TextEditingController ctrl, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AdminTheme.royalBlue, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildReadonlyCard(String label, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 18),
          const SizedBox(height: 12),
          Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateTile(String title, String preview) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(preview, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: const Icon(Icons.edit, size: 16, color: AdminTheme.royalBlue),
      ),
    );
  }
}
