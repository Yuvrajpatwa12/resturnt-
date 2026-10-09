import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class PaymentMethodListScreen extends StatefulWidget {
  final String mode;
  const PaymentMethodListScreen({super.key, this.mode = "Payment Method List"});

  @override
  State<PaymentMethodListScreen> createState() => _PaymentMethodListScreenState();
}

class _PaymentMethodListScreenState extends State<PaymentMethodListScreen> {
  String _selectedCategory = "ALL";
  String _searchQuery = "";
  bool _isLoading = true;

  List<Map<String, dynamic>> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    final fetched = await ApiService.fetchPaymentMethods(tenantId);

    if (mounted) {
      setState(() {
        if (fetched.isNotEmpty) {
          _paymentMethods = fetched.map((item) {
            final mId = (item['method_id'] ?? item['id'] ?? '').toString();
            return {
              'id': mId,
              'name': item['name'] ?? 'Payment Method',
              'category': (item['category'] ?? 'QR').toString().toUpperCase(),
              'type': item['type'] ?? 'Payment Channel',
              'accountHolder': item['account_holder_name'] ?? 'Main Account',
              'accountNumber': item['account_number'] ?? '',
              'bankProvider': item['bank_provider'] ?? '',
              'icon': _getIconForMethod(mId, item['category']),
              'color': _getColorForMethod(mId, item['category']),
              'isActive': item['is_active'] == true || item['is_active'] == 1 || item['is_active'] == '1',
              'isDefault': item['is_default'] == true || item['is_default'] == 1 || item['is_default'] == '1',
              'surcharge': item['surcharge'] ?? '0%',
              'minLimit': item['min_limit'] ?? 'NPR 0',
              'maxLimit': item['max_limit'] ?? 'No Limit',
              'description': item['description'] ?? 'Configured payment method',
            };
          }).toList();
        } else {
          _paymentMethods = [];
        }
        _isLoading = false;
      });
    }
  }

  IconData _getIconForMethod(String methodId, dynamic category) {
    switch (methodId.toLowerCase()) {
      case 'cash':
        return Icons.payments_rounded;
      case 'esewa':
        return Icons.account_balance_wallet_rounded;
      case 'fonepay':
        return Icons.qr_code_scanner_rounded;
      case 'khalti':
        return Icons.account_balance_wallet_outlined;
      case 'pos_card':
      case 'card':
        return Icons.credit_card_rounded;
      case 'bank_transfer':
      case 'bank':
        return Icons.account_balance_rounded;
      case 'cod':
        return Icons.local_shipping_rounded;
      default:
        final cat = (category ?? '').toString().toUpperCase();
        if (cat == 'CASH') return Icons.payments_rounded;
        if (cat == 'CARD') return Icons.credit_card_rounded;
        if (cat == 'BANK') return Icons.account_balance_rounded;
        return Icons.qr_code_2_rounded;
    }
  }

  Color _getColorForMethod(String methodId, dynamic category) {
    switch (methodId.toLowerCase()) {
      case 'cash':
        return const Color(0xFF10B981); // Emerald
      case 'esewa':
        return const Color(0xFF60BB46); // eSewa Green
      case 'fonepay':
        return const Color(0xFF1D4ED8); // Fonepay Blue
      case 'khalti':
        return const Color(0xFF5C2D91); // Khalti Purple
      case 'pos_card':
      case 'card':
        return const Color(0xFFF59E0B); // Amber
      case 'bank_transfer':
      case 'bank':
        return const Color(0xFF0284C7); // Sky Blue
      case 'cod':
        return const Color(0xFF64748B); // Slate
      default:
        return AdminTheme.royalBlue;
    }
  }

  Future<void> _toggleMethodStatus(Map<String, dynamic> method, bool newValue) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';
    final methodId = method['id'].toString();

    setState(() {
      method['isActive'] = newValue;
    });

    final success = await ApiService.togglePaymentMethodStatus(tenantId, methodId, newValue);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${method['name']} is now ${newValue ? 'ACTIVE' : 'DISABLED'} in POS & Database!"),
            backgroundColor: newValue ? AdminTheme.emeraldGreen : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${method['name']} state updated locally."),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _paymentMethods.where((method) {
      final matchesCat = _selectedCategory == "ALL" || method['category'] == _selectedCategory;
      final matchesSearch = method['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          method['type'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          method['accountHolder'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(),
          const SizedBox(height: 24),
          _buildStatsRow(),
          const SizedBox(height: 24),
          _buildFilterAndSearchBar(),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (filtered.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildMethodCard(filtered[index]);
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
          colors: [AdminTheme.darkNavy, AdminTheme.royalBlue],
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
            child: const Icon(Icons.payments_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Payment Method & Account List",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  "View and toggle active merchant payment options. To register new account profiles & QR codes (e.g. Ram Sharma), go to Payment Setup.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Text(
                  "REGISTER ACCOUNTS IN PAYMENT SETUP",
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final activeCount = _paymentMethods.where((m) => m['isActive'] == true).length;
    final totalCount = _paymentMethods.length;

    return Row(
      children: [
        Expanded(child: _buildStatCard("Active Gateways", "$activeCount / $totalCount", Icons.check_circle_outline_rounded, AdminTheme.emeraldGreen)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard("QR / Digital Wallets", "${_paymentMethods.where((m) => m['category'] == 'QR' && m['isActive'] == true).length} Active", Icons.qr_code_2_rounded, AdminTheme.royalBlue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard("Card Terminals", "${_paymentMethods.where((m) => m['category'] == 'CARD' && m['isActive'] == true).length} Active", Icons.credit_card_rounded, Colors.orange)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard("Default Method", "Cash", Icons.star_rounded, Colors.purple)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchBar() {
    final categories = [
      {'key': 'ALL', 'label': 'All Methods'},
      {'key': 'CASH', 'label': 'Cash & COD'},
      {'key': 'QR', 'label': 'QR & Wallets'},
      {'key': 'CARD', 'label': 'Card / POS'},
      {'key': 'BANK', 'label': 'Bank Transfer'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Search method, account holder name, or type...",
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                    filled: true,
                    fillColor: AdminTheme.pearlWhite,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat['label']!),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat['key']!),
                    selectedColor: AdminTheme.royalBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AdminTheme.darkNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    backgroundColor: AdminTheme.pearlWhite,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard(Map<String, dynamic> method) {
    final Color color = method['color'] as Color;
    final bool isActive = method['isActive'] as bool;
    final bool isDefault = method['isDefault'] as bool;
    final String holder = method['accountHolder'].toString();
    final String number = method['accountNumber'].toString();

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
            child: Icon(method['icon'] as IconData, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method['name'],
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
                    ),
                    const SizedBox(width: 10),
                    if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "DEFAULT",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminTheme.royalBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 12, color: AdminTheme.royalBlue),
                          const SizedBox(width: 4),
                          Text(
                            "Account Holder: $holder",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                          ),
                        ],
                      ),
                    ),
                    if (number.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text("• No: $number", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  method['description'],
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildMetaChip("Surcharge", method['surcharge'], Icons.percent_rounded),
                    _buildMetaChip("Min Limit", method['minLimit'], Icons.arrow_downward_rounded),
                    _buildMetaChip("Max Limit", method['maxLimit'], Icons.arrow_upward_rounded),
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
                    onChanged: (val) => _toggleMethodStatus(method, val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showEditMethodModal(context, method),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTheme.royalBlue,
                  side: const BorderSide(color: AdminTheme.royalBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text("CONFIGURE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        children: const [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text("No Payment Methods Found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text("Try searching with different terms or select 'All Methods'.", style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  void _showEditMethodModal(BuildContext context, Map<String, dynamic> method) {
    final holderNameCtrl = TextEditingController(text: method['accountHolder']);
    final accountNumberCtrl = TextEditingController(text: method['accountNumber']);
    final surchargeCtrl = TextEditingController(text: method['surcharge']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Configure ${method['name']}", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
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
              controller: surchargeCtrl,
              decoration: const InputDecoration(labelText: "Surcharge Rate (e.g. 0% or 1.5%)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final tenant = TenantService().currentTenant.value;
              final tenantId = tenant?.id ?? 'startups_main';

              final bool isActiveBool = method['isActive'] == true || method['isActive'] == 1 || method['isActive'] == '1';
              final bool isDefaultBool = method['isDefault'] == true || method['isDefault'] == 1 || method['isDefault'] == '1';

              final methodData = {
                'method_id': method['id'],
                'name': method['name'],
                'category': method['category'],
                'type': method['type'],
                'account_holder_name': holderNameCtrl.text.trim(),
                'account_number': accountNumberCtrl.text.trim(),
                'bank_provider': method['bankProvider'],
                'is_active': isActiveBool ? 1 : 0,
                'is_default': isDefaultBool ? 1 : 0,
                'surcharge': surchargeCtrl.text.trim(),
                'min_limit': method['minLimit'],
                'max_limit': method['maxLimit'],
                'description': method['description'],
              };

              final messenger = ScaffoldMessenger.of(context);
              setState(() {
                method['accountHolder'] = holderNameCtrl.text.trim();
                method['accountNumber'] = accountNumberCtrl.text.trim();
                method['surcharge'] = surchargeCtrl.text.trim();
              });

              Navigator.pop(ctx);
              ApiService.savePaymentMethod(tenantId, methodData).then((success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? "${method['name']} account profile saved to Database!" : "Saved locally."),
                    backgroundColor: AdminTheme.emeraldGreen,
                  ),
                );
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
            child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
