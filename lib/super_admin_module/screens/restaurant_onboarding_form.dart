import 'package:flutter/material.dart';
import '../styles.dart';

class RestaurantOnboardingForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onRegister;
  final VoidCallback onCancel;

  const RestaurantOnboardingForm({
    super.key,
    required this.onRegister,
    required this.onCancel,
  });

  @override
  State<RestaurantOnboardingForm> createState() => _RestaurantOnboardingFormState();
}

class _RestaurantOnboardingFormState extends State<RestaurantOnboardingForm> {
  final _nameController = TextEditingController();
  final _tenantIdController = TextEditingController();
  final _subdomainController = TextEditingController();
  final _emailController = TextEditingController(); // Added Email Controller
  final _pinController = TextEditingController(text: "1234");
  final _latController = TextEditingController(); // Added Latitude
  final _lngController = TextEditingController(); // Added Longitude
  
  String _selectedPlan = "Basic";
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _tenantIdController.dispose();
    _subdomainController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          
          if (_isSubmitting)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSectionCard("1. General Information", [
                        _buildTextField("Restaurant Name", _nameController, hint: "e.g. Everest Cafe"),
                        _buildTextField("Custom Domain", _subdomainController, hint: "everestcafe.com"),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionCard("2. System Identity", [
                        _buildTextField("Unique Tenant ID", _tenantIdController, hint: "e.g. everest_01"),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionCard("5. Geofencing (GPS)", [
                        _buildTextField("Latitude", _latController, hint: "e.g. 27.7172"),
                        _buildTextField("Longitude", _lngController, hint: "e.g. 85.3240"),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _buildSectionCard("3. Subscription", [
                        _buildDropdownField("Plan", ["Basic", "Pro", "Enterprise"], _selectedPlan, (val) => setState(() => _selectedPlan = val!)),
                        const SizedBox(height: 16),
                        _buildDatePickerTile("Expiry Date", _expiryDate),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionCard("4. Security & Access", [
                        _buildTextField("Admin Email Address", _emailController, hint: "owner@cafe.com"), // UI for Email
                        _buildTextField("Initial Admin PIN", _pinController, hint: "1234"),
                      ]),
                      const SizedBox(height: 40),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Onboard New Restaurant", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text("Register a new instance onto the SaaS platform.", style: TextStyle(color: SAMStyles.textGrey)),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SAMStyles.royalBlue)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SAMStyles.textGrey)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: SAMStyles.pearlWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> items, String value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SAMStyles.textGrey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: SAMStyles.pearlWhite, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerTile(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SAMStyles.textGrey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
            );
            if (picked != null) setState(() => _expiryDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: SAMStyles.pearlWhite, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.calendar_today, size: 18, color: SAMStyles.royalBlue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
            child: const Text("CANCEL"),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (_nameController.text.isEmpty || _tenantIdController.text.isEmpty || _subdomainController.text.isEmpty || _emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields including Email are required!")));
                return;
              }
              
              setState(() => _isSubmitting = true);
              
              final newTenantData = {
                'name': _nameController.text,
                'tenant_id': _tenantIdController.text,
                'domain': _subdomainController.text,
                'email': _emailController.text.trim(), // Include Email in payload
                'plan': _selectedPlan,
                'expiry': "${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}",
                'admin_pin': _pinController.text,
                'latitude': double.tryParse(_latController.text.trim()) ?? 0.0,
                'longitude': double.tryParse(_lngController.text.trim()) ?? 0.0,
              };
              
              widget.onRegister(newTenantData);
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 54)),
            child: const Text("REGISTER RESTAURANT"),
          ),
        ),
      ],
    );
  }
}
