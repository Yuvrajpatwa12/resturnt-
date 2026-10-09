import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class PaymentSetupScreen extends StatefulWidget {
  final String mode;
  const PaymentSetupScreen({super.key, this.mode = "Payment Setup"});

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    setState(() => _isLoading = true);
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    final methods = await ApiService.fetchPaymentMethods(tenantId);
    if (mounted) {
      setState(() {
        _savedAccounts = methods;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount(Map<String, dynamic> acc) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';
    final methodId = acc['method_id'] ?? acc['id'] ?? '';

    setState(() {
      _savedAccounts.removeWhere((item) => (item['method_id'] ?? item['id']) == methodId);
    });

    await ApiService.deletePaymentMethod(tenantId, methodId.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Account profile '${acc['name']}' deleted.")),
      );
    }
  }

  Future<void> _toggleAccountStatus(Map<String, dynamic> acc, bool newValue) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';
    final methodId = (acc['method_id'] ?? acc['id'] ?? '').toString();

    setState(() {
      acc['is_active'] = newValue;
    });

    await ApiService.togglePaymentMethodStatus(tenantId, methodId, newValue);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${acc['name']} is now ${newValue ? 'ACTIVE' : 'DISABLED'} in POS & Database!"),
          backgroundColor: newValue ? AdminTheme.emeraldGreen : Colors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(),
          const SizedBox(height: 24),
          _buildAccountsHeader(),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_savedAccounts.isEmpty)
            _buildEmptyAccountsCard()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _savedAccounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildAccountProfileCard(_savedAccounts[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminTheme.darkNavy, Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Payment Setup & Account Registration",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  "Add and manage payment accounts with account holder details (e.g. Ram Sharma). Saved accounts auto-sync to Payment Method List & POS Invoice.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddAccountModal(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.emeraldGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 20),
            label: const Text("ADD PAYMENT ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Registered Payment Accounts & QR Profiles",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
        ),
        Text(
          "${_savedAccounts.length} Profiles Configured",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAccountProfileCard(Map<String, dynamic> acc) {
    final holder = (acc['account_holder_name'] ?? 'Main Account').toString();
    final provider = (acc['bank_provider'] ?? acc['name'] ?? 'Provider').toString();
    final number = (acc['account_number'] ?? '').toString();
    final bool isActive = acc['is_active'] == true || acc['is_active'] == 1 || acc['is_active'] == '1';
    final category = (acc['category'] ?? 'QR').toString();

    IconData icon = Icons.qr_code_2_rounded;
    Color color = AdminTheme.royalBlue;

    if (category == 'CASH') {
      icon = Icons.payments_rounded;
      color = const Color(0xFF10B981);
    } else if (category == 'CARD') {
      icon = Icons.credit_card_rounded;
      color = Colors.orange;
    } else if (category == 'BANK') {
      icon = Icons.account_balance_rounded;
      color = const Color(0xFF0284C7);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      acc['name'] ?? provider,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        provider,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AdminTheme.royalBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 14, color: AdminTheme.royalBlue),
                          const SizedBox(width: 6),
                          Text(
                            "Account Holder: $holder",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                          ),
                        ],
                      ),
                    ),
                    if (number.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text("• Number: $number", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                if ((acc['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    acc['description'].toString(),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    _buildMetaChip("Surcharge", acc['surcharge'] ?? '0%', Icons.percent_rounded),
                    _buildMetaChip("Min Limit", acc['min_limit'] ?? 'NPR 0', Icons.arrow_downward_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    isActive ? "ACTIVE" : "DISABLED",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AdminTheme.emeraldGreen : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: isActive,
                    activeThumbColor: AdminTheme.emeraldGreen,
                    onChanged: (val) => _toggleAccountStatus(acc, val),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showEditAccountModal(context, acc),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminTheme.royalBlue,
                      side: const BorderSide(color: AdminTheme.royalBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text("EDIT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteAccount(acc),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    tooltip: "Delete Account",
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminTheme.pearlWhite,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text("$label: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        ],
      ),
    );
  }

  Widget _buildEmptyAccountsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 54, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No Payment Accounts Configured", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
          const SizedBox(height: 6),
          const Text("Click the button below to register a new payment account & merchant QR profile.", style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddAccountModal(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.royalBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 20),
            label: const Text("REGISTER FIRST PAYMENT ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddAccountModal(BuildContext context) {
    final holderNameCtrl = TextEditingController();
    final accountNumberCtrl = TextEditingController();
    final providerCtrl = TextEditingController();
    final surchargeCtrl = TextEditingController(text: "0%");
    final descriptionCtrl = TextEditingController();
    String category = 'QR';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              top: 24,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Register New Payment Account", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: holderNameCtrl,
                    decoration: InputDecoration(
                      labelText: "Account Holder Name *",
                      hintText: "e.g. Ram Sharma / Restro Main Account",
                      prefixIcon: const Icon(Icons.person_rounded, color: AdminTheme.royalBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: accountNumberCtrl,
                          decoration: InputDecoration(
                            labelText: "Account / Mobile Number *",
                            hintText: "e.g. 9841234567 or 019010...",
                            prefixIcon: const Icon(Icons.numbers_rounded, color: AdminTheme.royalBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: providerCtrl,
                          decoration: InputDecoration(
                            labelText: "Bank / Provider Name *",
                            hintText: "e.g. eSewa / Fonepay / Nabil Bank",
                            prefixIcon: const Icon(Icons.domain_rounded, color: AdminTheme.royalBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: "Category / Type",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'QR', child: Text("QR Code & Mobile Wallet")),
                      DropdownMenuItem(value: 'CASH', child: Text("Cash Register")),
                      DropdownMenuItem(value: 'CARD', child: Text("Card POS Terminal")),
                      DropdownMenuItem(value: 'BANK', child: Text("Direct Bank Transfer")),
                    ],
                    onChanged: (val) => setModalState(() => category = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: surchargeCtrl,
                    decoration: InputDecoration(
                      labelText: "Surcharge Rate",
                      hintText: "e.g. 0% or 1.5%",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionCtrl,
                    decoration: InputDecoration(
                      labelText: "Instructions / Remarks",
                      hintText: "Short note for cashier or customer",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final holderName = holderNameCtrl.text.trim();
                        final provider = providerCtrl.text.trim();
                        if (holderName.isNotEmpty && provider.isNotEmpty) {
                          final tenant = TenantService().currentTenant.value;
                          final tenantId = tenant?.id ?? 'startups_main';
                          final methodId = '${provider.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

                          final newMethodPayload = {
                            'method_id': methodId,
                            'name': '$provider ($holderName)',
                            'category': category,
                            'type': '$category Profile',
                            'account_holder_name': holderName,
                            'account_number': accountNumberCtrl.text.trim(),
                            'bank_provider': provider,
                            'is_active': 1,
                            'is_default': 0,
                            'surcharge': surchargeCtrl.text.trim().isEmpty ? '0%' : surchargeCtrl.text.trim(),
                            'min_limit': 'NPR 0',
                            'max_limit': 'No Limit',
                            'description': descriptionCtrl.text.trim(),
                          };

                          Navigator.pop(ctx);
                          await ApiService.savePaymentMethod(tenantId, newMethodPayload);
                          await _loadSavedAccounts();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Payment Account '$provider ($holderName)' Registered & Saved!"),
                                backgroundColor: AdminTheme.emeraldGreen,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.royalBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("REGISTER PAYMENT ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditAccountModal(BuildContext context, Map<String, dynamic> acc) {
    final holderNameCtrl = TextEditingController(text: (acc['account_holder_name'] ?? '').toString());
    final accountNumberCtrl = TextEditingController(text: (acc['account_number'] ?? '').toString());
    final providerCtrl = TextEditingController(text: (acc['bank_provider'] ?? acc['name'] ?? '').toString());
    final surchargeCtrl = TextEditingController(text: (acc['surcharge'] ?? '0%').toString());
    final descriptionCtrl = TextEditingController(text: (acc['description'] ?? '').toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Edit ${acc['name']}", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: holderNameCtrl,
              decoration: const InputDecoration(labelText: "Account Holder Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: accountNumberCtrl,
              decoration: const InputDecoration(labelText: "Account / Mobile Number"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: providerCtrl,
              decoration: const InputDecoration(labelText: "Bank / Provider Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: surchargeCtrl,
              decoration: const InputDecoration(labelText: "Surcharge Rate"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final tenant = TenantService().currentTenant.value;
              final tenantId = tenant?.id ?? 'startups_main';

              final bool isActiveBool = acc['is_active'] == true || acc['is_active'] == 1 || acc['is_active'] == '1';
              final bool isDefaultBool = acc['is_default'] == true || acc['is_default'] == 1 || acc['is_default'] == '1';

              final updatedData = {
                'method_id': acc['method_id'] ?? acc['id'],
                'name': '${providerCtrl.text.trim()} (${holderNameCtrl.text.trim()})',
                'category': acc['category'] ?? 'QR',
                'type': acc['type'] ?? 'Custom Profile',
                'account_holder_name': holderNameCtrl.text.trim(),
                'account_number': accountNumberCtrl.text.trim(),
                'bank_provider': providerCtrl.text.trim(),
                'is_active': isActiveBool ? 1 : 0,
                'is_default': isDefaultBool ? 1 : 0,
                'surcharge': surchargeCtrl.text.trim(),
                'min_limit': acc['min_limit'] ?? 'NPR 0',
                'max_limit': acc['max_limit'] ?? 'No Limit',
                'description': descriptionCtrl.text.trim(),
              };

              Navigator.pop(ctx);
              await ApiService.savePaymentMethod(tenantId, updatedData);
              await _loadSavedAccounts();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Account profile updated in Database!"),
                    backgroundColor: AdminTheme.emeraldGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
            child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
