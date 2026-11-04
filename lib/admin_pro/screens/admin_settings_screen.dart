import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../admin_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  final String section;
  const AdminSettingsScreen({super.key, required this.section});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _autoPrint = true;
  bool _soundEnabled = true;
  double _volume = 0.8;
  final TextEditingController _vatController = TextEditingController();
  final TextEditingController _serviceChargeController =
      TextEditingController();
  bool _isLoadingBillingSettings = false;
  bool _isSavingBillingSettings = false;
  String? _billingSettingsError;

  @override
  void initState() {
    super.initState();
    if (widget.section == 'POS Setting') {
      _loadBillingSettings();
    }
  }

  @override
  void dispose() {
    _vatController.dispose();
    _serviceChargeController.dispose();
    super.dispose();
  }

  Future<void> _loadBillingSettings() async {
    setState(() => _isLoadingBillingSettings = true);
    final result = await ApiService.getBillingSettings();
    if (!mounted) return;
    setState(() {
      _isLoadingBillingSettings = false;
      if (result['success'] == true) {
        _vatController.text = result['vat_percentage'].toString();
        _serviceChargeController.text = result['service_charge'].toString();
        _billingSettingsError = null;
      } else {
        _billingSettingsError =
            result['message']?.toString() ??
            'Could not load billing rates. Configure them before billing.';
      }
    });
  }

  Future<void> _saveBillingSettings() async {
    final vat = double.tryParse(_vatController.text.trim());
    final serviceCharge = double.tryParse(_serviceChargeController.text.trim());
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
          content: Text('Enter VAT and service charge from 0 to 100%.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingBillingSettings = true);
    final result = await ApiService.saveBillingSettings(
      vatPercentage: vat,
      serviceCharge: serviceCharge,
    );
    if (!mounted) return;
    setState(() {
      _isSavingBillingSettings = false;
      _billingSettingsError = result['success'] == true
          ? null
          : result['message']?.toString() ?? 'Could not save billing rates.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'VAT and service charge saved.'
              : _billingSettingsError!,
        ),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.section == 'POS Setting') ...[
            _buildBillingRatesGroup(),
            const SizedBox(height: 24),
          ],
          _buildSettingsGroup("General Configuration", [
            _buildToggleTile(
              "Automatic KOT Print",
              "Print tickets instantly when order is received",
              _autoPrint,
              (v) => setState(() => _autoPrint = v),
            ),
            _buildToggleTile(
              "Enable Sound Alerts",
              "Play sound for new incoming orders",
              _soundEnabled,
              (v) => setState(() => _soundEnabled = v),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsGroup("Audio Levels", [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Notification Volume",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Slider(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                    activeColor: AdminTheme.royalBlue,
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsGroup("Terminal Info", [
            _buildInfoTile("Terminal ID", "POS-TERM-0982"),
            _buildInfoTile("Connection", "Connected (Stable)"),
            _buildInfoTile("App Version", "v2.4.1 (Stable Build)"),
          ]),
          const SizedBox(height: 40),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text(
                "RESTORE DEFAULT SETTINGS",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingRatesGroup() {
    return _buildSettingsGroup('Billing Rates', [
      if (_isLoadingBillingSettings)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        _buildPercentageField(
          label: 'VAT (%)',
          controller: _vatController,
          hint: 'e.g. 13',
        ),
        _buildPercentageField(
          label: 'Service Charge (%)',
          controller: _serviceChargeController,
          hint: 'e.g. 10',
        ),
        if (_billingSettingsError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _billingSettingsError!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSavingBillingSettings ? null : _saveBillingSettings,
              icon: _isSavingBillingSettings
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSavingBillingSettings ? 'Saving...' : 'Save Billing Rates',
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _buildPercentageField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: '%',
          helperText: 'Enter a value from 0 to 100. Use 0 to disable.',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AdminTheme.softShadow,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleTile(
    String title,
    String sub,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AdminTheme.emeraldGreen,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        sub,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          color: AdminTheme.royalBlue,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
