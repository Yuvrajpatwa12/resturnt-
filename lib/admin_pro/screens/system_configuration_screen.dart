import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin_theme.dart';
import '../../services/language_service.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';

class SystemConfigurationScreen extends StatefulWidget {
  final String mode;
  const SystemConfigurationScreen({super.key, required this.mode});

  @override
  State<SystemConfigurationScreen> createState() =>
      _SystemConfigurationScreenState();
}

class _SystemConfigurationScreenState extends State<SystemConfigurationScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _billingSettingsError;

  Map<String, dynamic> _configState = {
    "restaurant_name": "Chiyalaa Global Hub",
    "restaurant_id": "CHY-PRO-9901",
    "location": "Main Road, Butwal, Nepal",
    "contact_email": "admin@chiyalaa.com",
    "contact_phone": "+977-98XXXXXXXX",
    "currency": "NPR",
    "timezone": "Asia/Kathmandu",
    "sms_sender_id": "CHIYALAA",
    "subscription_plan": "ENTERPRISE ELITE",
  };

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _vatController = TextEditingController();
  final TextEditingController _serviceChargeController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _vatController.dispose();
    _serviceChargeController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant != null) {
      _configState['restaurant_name'] = tenant.name;
      _configState['contact_email'] =
          tenant.contactEmail ?? _configState['contact_email'];
      _configState['contact_phone'] =
          tenant.contactPhone ?? _configState['contact_phone'];
      _configState['location'] = tenant.location ?? _configState['location'];
      _configState['currency'] = tenant.currencyCode;
      _configState['subscription_plan'] = tenant.plan;
    }

    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString('system_config_data');
    if (saved != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(saved);
        _configState.addAll(decoded);
      } catch (_) {}
    }
    _configState.remove('vat_percentage');
    _configState.remove('service_charge');

    final billingSettings = await ApiService.getBillingSettings();
    if (billingSettings['success'] == true) {
      _vatController.text = billingSettings['vat_percentage'].toString();
      _serviceChargeController.text = billingSettings['service_charge']
          .toString();
      _configState['vat_percentage'] = billingSettings['vat_percentage'];
      _configState['service_charge'] = billingSettings['service_charge'];
      _billingSettingsError = null;
    } else {
      _vatController.clear();
      _serviceChargeController.clear();
      _billingSettingsError = billingSettings['message']?.toString();
    }

    _populateControllers();
    if (mounted) setState(() => _isLoading = false);
  }

  void _populateControllers() {
    final tenant = TenantService().currentTenant.value;
    _nameController.text = (tenant?.name.isNotEmpty == true)
        ? tenant!.name
        : (_configState['restaurant_name'] ?? "");
    _emailController.text = (tenant?.contactEmail?.isNotEmpty == true)
        ? tenant!.contactEmail!
        : (_configState['contact_email'] ?? "");
    _phoneController.text = (tenant?.contactPhone?.isNotEmpty == true)
        ? tenant!.contactPhone!
        : (_configState['contact_phone'] ?? "");
    _addressController.text = (tenant?.location?.isNotEmpty == true)
        ? tenant!.location!
        : (_configState['location'] ?? "");
  }

  Future<void> _saveConfig() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';
    final isApplicationSettings = widget.mode == 'Application Setting';
    double? vat;
    double? serviceCharge;
    if (isApplicationSettings) {
      vat = double.tryParse(_vatController.text.trim());
      serviceCharge = double.tryParse(_serviceChargeController.text.trim());
      if (vat == null ||
          serviceCharge == null ||
          !vat.isFinite ||
          !serviceCharge.isFinite ||
          vat < 0 ||
          vat > 100 ||
          serviceCharge < 0 ||
          serviceCharge > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter VAT and service charge rates from 0 to 100. Use 0 for no charge.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final res = await ApiService.updateTenantProfile(
      tenantId: tenantId,
      restaurantName: _nameController.text.trim(),
      contactEmail: _emailController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      location: _addressController.text.trim(),
    );
    final billingRes = isApplicationSettings
        ? await ApiService.saveBillingSettings(
            vatPercentage: vat!,
            serviceCharge: serviceCharge!,
          )
        : null;

    _configState['restaurant_name'] = _nameController.text.trim();
    _configState['contact_email'] = _emailController.text.trim();
    _configState['contact_phone'] = _phoneController.text.trim();
    _configState['location'] = _addressController.text.trim();
    if (billingRes?['success'] == true) {
      _configState['vat_percentage'] = billingRes!['vat_percentage'];
      _configState['service_charge'] = billingRes['service_charge'];
      _billingSettingsError = null;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('system_config_data', json.encode(_configState));

    if (tenant != null) {
      await TenantService().initialize(tenant.domain, showLoading: false);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      final bool isSuccess =
          res['success'] == true &&
          (billingRes == null || billingRes['success'] == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSuccess
                ? "Restaurant profile and billing rates saved to the database."
                : "Profile: ${res['message'] ?? 'save failed'} Billing rates: ${billingRes?['message'] ?? 'not changed'}",
          ),
          backgroundColor: isSuccess ? Colors.green : Colors.orange,
        ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.mode,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.darkNavy,
                ),
              ),
              const Text(
                "Global system environment and business rules.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveConfig,
            icon: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(_isSaving ? "SAVING..." : "SYNC CHANGES"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.royalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
        _buildConfigInput(
          "Business Address",
          _addressController,
          Icons.location_on_outlined,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildConfigInput(
                "Admin Notification Email (For Tickets, Stock & Subscription Alerts)",
                _emailController,
                Icons.email_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildConfigInput(
                "Support Phone",
                _phoneController,
                Icons.phone_android,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        _buildSectionTitle("FINANCIAL ENVIRONMENT"),
        const SizedBox(height: 24),
        if (_billingSettingsError != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              border: Border.all(color: const Color(0xFFF97316)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Billing rates are not available from the server: '
              '$_billingSettingsError. Enter both rates below and save to configure them.',
              style: const TextStyle(color: Color(0xFF9A3412)),
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: _buildReadonlyCard(
                "Currency",
                _configState['currency'],
                Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRateInput(
                "VAT Percentage",
                _vatController,
                Icons.percent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRateInput(
                "Service Charge",
                _serviceChargeController,
                Icons.room_service_outlined,
              ),
            ),
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
        _buildConfigCard(
          "Cash Payment",
          "Active",
          Icons.payments_outlined,
          AdminTheme.emeraldGreen,
        ),
        _buildConfigCard(
          "Fonepay (QR)",
          "Active",
          Icons.qr_code_scanner,
          AdminTheme.royalBlue,
        ),
        _buildConfigCard(
          "Bank Card Terminal",
          "Offline",
          Icons.credit_card_outlined,
          Colors.red,
        ),
        _buildConfigCard(
          "eSewa Wallet",
          "Active",
          Icons.account_balance_wallet_outlined,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildSMSConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("GATEWAY STATUS"),
        const SizedBox(height: 24),
        _buildConfigCard(
          "Sender ID: ${_configState['sms_sender_id']}",
          "Configured",
          Icons.sms,
          AdminTheme.royalBlue,
        ),
        const SizedBox(height: 48),
        _buildSectionTitle("MESSAGE TEMPLATES"),
        const SizedBox(height: 16),
        _buildTemplateTile(
          "Reservation Confirmed",
          "Dear [Name], your table is booked...",
        ),
        _buildTemplateTile(
          "Order Ready",
          "Your order #[ID] is ready for pickup!",
        ),
        _buildTemplateTile(
          "Payment Received",
          "Thank you! We received your payment...",
        ),
      ],
    );
  }

  Widget _buildBankConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("CONNECTED CORPORATE ACCOUNTS"),
        const SizedBox(height: 24),
        _buildConfigCard(
          "Global IME Bank",
          "Verified",
          Icons.account_balance,
          Colors.indigo,
        ),
        _buildConfigCard(
          "NIC Asia Bank",
          "Active",
          Icons.account_balance,
          Colors.red,
        ),
        _buildConfigCard(
          "Nabil Bank Ltd",
          "Pending",
          Icons.account_balance,
          Colors.orange,
        ),
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
            ...LanguageService().languages.value.map(
              (l) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: l.code == currentCode
                        ? AdminTheme.royalBlue
                        : Colors.grey.shade100,
                    width: 2,
                  ),
                  boxShadow: AdminTheme.softShadow,
                ),
                child: ListTile(
                  onTap: () => LanguageService().setLanguage(l.code),
                  leading: CircleAvatar(
                    backgroundColor: l.code == currentCode
                        ? AdminTheme.royalBlue
                        : Colors.grey.shade100,
                    child: Text(
                      l.code.toUpperCase(),
                      style: TextStyle(
                        color: l.code == currentCode
                            ? Colors.white
                            : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    l.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    l.nativeName,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: l.code == currentCode
                      ? const Icon(
                          Icons.check_circle,
                          color: AdminTheme.royalBlue,
                        )
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGenericConfig() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tune, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            "Configuration for ${widget.mode} coming soon.",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildConfigInput(
    String label,
    TextEditingController ctrl,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
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

  Widget _buildRateInput(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
        ],
        decoration: InputDecoration(
          labelText: '$label (0-100%)',
          suffixText: '%',
          prefixIcon: Icon(icon, color: AdminTheme.royalBlue, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildReadonlyCard(String label, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 18),
          const SizedBox(height: 12),
          Text(
            val,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AdminTheme.darkNavy,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard(
    String title,
    String status,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: AdminTheme.darkNavy, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateTile(String title, String preview) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          preview,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: const Icon(Icons.edit, size: 16, color: AdminTheme.royalBlue),
      ),
    );
  }
}
