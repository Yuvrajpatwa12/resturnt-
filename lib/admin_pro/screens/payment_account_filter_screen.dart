import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class PaymentAccountFilterScreen extends StatefulWidget {
  final String mode;
  const PaymentAccountFilterScreen({super.key, this.mode = "Payment Account Filter"});

  @override
  State<PaymentAccountFilterScreen> createState() => _PaymentAccountFilterScreenState();
}

class _PaymentAccountFilterScreenState extends State<PaymentAccountFilterScreen> {
  String _selectedAccountId = "ALL";
  String _dateRange = "ALL"; // TODAY, WEEK, MONTH, ALL
  String _searchQuery = "";
  bool _isLoading = true;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _allOrders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    final fetchedAccounts = await ApiService.fetchPaymentMethods(tenantId);
    final fetchedOrders = await ApiService.fetchAllOrders(tenantId) ?? [];

    if (mounted) {
      setState(() {
        _accounts = fetchedAccounts;
        _allOrders = fetchedOrders;
        _isLoading = false;
      });
    }
  }

  double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  bool _matchesDateRange(dynamic dateStr) {
    if (_dateRange == "ALL" || dateStr == null) return true;
    final String str = dateStr.toString().trim();
    final DateTime? dt = DateTime.tryParse(str);
    if (dt == null) return true;

    final now = DateTime.now();
    if (_dateRange == "TODAY") {
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } else if (_dateRange == "WEEK") {
      final diff = now.difference(dt).inDays;
      return diff <= 7;
    } else if (_dateRange == "MONTH") {
      return dt.year == now.year && dt.month == now.month;
    }
    return true;
  }

  bool _isOrderMatchingAccount(Map<String, dynamic> order, Map<String, dynamic>? account) {
    if (account == null) return true; // "ALL" option

    final String methodInOrder = (order['payment_method'] ?? order['method'] ?? 'Cash').toString().toLowerCase();
    final String accId = (account['method_id'] ?? account['id'] ?? '').toString().toLowerCase();
    final String accName = (account['name'] ?? '').toString().toLowerCase();
    final String holder = (account['account_holder_name'] ?? '').toString().toLowerCase();
    final String provider = (account['bank_provider'] ?? '').toString().toLowerCase();

    if (methodInOrder.contains(accId) || methodInOrder.contains(accName)) return true;
    if (holder.isNotEmpty && holder != 'main account' && methodInOrder.contains(holder)) return true;
    if (provider.isNotEmpty && methodInOrder.contains(provider)) return true;

    return false;
  }

  double _calculateAccountRevenue(Map<String, dynamic>? account) {
    double sum = 0.0;
    for (var ord in _allOrders) {
      if (!_matchesDateRange(ord['created_at'] ?? ord['date'])) continue;
      if (_isOrderMatchingAccount(ord, account)) {
        sum += _parseAmount(ord['total_amount'] ?? ord['total']);
      }
    }
    return sum;
  }

  int _calculateAccountBillCount(Map<String, dynamic>? account) {
    int count = 0;
    for (var ord in _allOrders) {
      if (!_matchesDateRange(ord['created_at'] ?? ord['date'])) continue;
      if (_isOrderMatchingAccount(ord, account)) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? currentAccount;
    if (_selectedAccountId != "ALL") {
      currentAccount = _accounts.firstWhere(
        (a) => (a['method_id'] ?? a['id']).toString() == _selectedAccountId,
        orElse: () => {},
      );
      if (currentAccount.isEmpty) currentAccount = null;
    }

    final filteredOrders = _allOrders.where((ord) {
      if (!_matchesDateRange(ord['created_at'] ?? ord['date'])) return false;
      if (!_isOrderMatchingAccount(ord, currentAccount)) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final id = (ord['id'] ?? ord['order_id'] ?? '').toString().toLowerCase();
        final customer = (ord['customer_name'] ?? ord['user_id'] ?? '').toString().toLowerCase();
        final method = (ord['payment_method'] ?? ord['method'] ?? '').toString().toLowerCase();

        return id.contains(q) || customer.contains(q) || method.contains(q);
      }
      return true;
    }).toList();

    final double totalRestaurantRevenue = _calculateAccountRevenue(null);
    final double selectedRevenue = _calculateAccountRevenue(currentAccount);
    final int selectedCount = filteredOrders.length;
    final double sharePercent = totalRestaurantRevenue > 0 ? (selectedRevenue / totalRestaurantRevenue) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(),
          const SizedBox(height: 24),
          _buildAccountLedgerGrid(),
          const SizedBox(height: 24),
          _buildAccountFilterBar(),
          const SizedBox(height: 24),
          _buildStatsRow(selectedRevenue, selectedCount, sharePercent, totalRestaurantRevenue),
          const SizedBox(height: 24),
          _buildDateAndSearchFilterBar(),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (filteredOrders.isEmpty)
            _buildEmptyStateCard(currentAccount)
          else
            _buildBilledTransactionsList(filteredOrders),
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
            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Payment Account Ledger & Balance Audit",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  "Audit total bill revenue credited to each payment account and wallet profile (e.g. Khalti iphone). See when and how much was billed.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loadData,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("REFRESH BALANCE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountLedgerGrid() {
    if (_accounts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.account_balance_wallet_rounded, color: AdminTheme.royalBlue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "REGISTERED PAYMENT ACCOUNTS & BALANCES",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
                  ),
                ],
              ),
              Text("${_accounts.length} Accounts Active", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _accounts.map((acc) {
                final holder = (acc['account_holder_name'] ?? 'Main Account').toString();
                final provider = (acc['bank_provider'] ?? acc['name'] ?? 'Provider').toString();
                final number = (acc['account_number'] ?? '').toString();
                final double rev = _calculateAccountRevenue(acc);
                final int bills = _calculateAccountBillCount(acc);

                return Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AdminTheme.pearlWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              provider,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "$bills Bills Cleared",
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: AdminTheme.darkNavy),
                          const SizedBox(width: 6),
                          Text(
                            holder,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy),
                          ),
                        ],
                      ),
                      if (number.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text("No: $number", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        "NPR ${rev.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AdminTheme.emeraldGreen),
                      ),
                      const Text(
                        "Total Credited Balance",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.filter_list_rounded, color: AdminTheme.royalBlue, size: 20),
              SizedBox(width: 8),
              Text(
                "AUDIT TRANSACTIONS FOR ACCOUNT PROFILE",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAccountChip("ALL", "All Payment Accounts", null),
                ..._accounts.map((acc) {
                  final id = (acc['method_id'] ?? acc['id']).toString();
                  final name = acc['name'] ?? 'Account';
                  return _buildAccountChip(id, name, acc);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountChip(String id, String title, Map<String, dynamic>? acc) {
    final bool isSelected = _selectedAccountId == id;
    final double revenue = _calculateAccountRevenue(acc);

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedAccountId = id),
        selectedColor: AdminTheme.royalBlue,
        backgroundColor: AdminTheme.pearlWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : AdminTheme.darkNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : AdminTheme.royalBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "NPR ${revenue.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : AdminTheme.royalBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(double selectedRevenue, int selectedCount, double sharePercent, double totalRevenue) {
    return Row(
      children: [
        Expanded(child: _buildStatCard("Selected Account Revenue", "NPR ${selectedRevenue.toStringAsFixed(0)}", Icons.account_balance_wallet_rounded, AdminTheme.emeraldGreen)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard("Processed Bills", "$selectedCount Bills", Icons.receipt_rounded, AdminTheme.royalBlue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard("Revenue Share", "${sharePercent.toStringAsFixed(1)}%", Icons.pie_chart_rounded, Colors.purple)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard("Total Store Sales", "NPR ${totalRevenue.toStringAsFixed(0)}", Icons.payments_rounded, Colors.amber.shade800)),
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

  Widget _buildDateAndSearchFilterBar() {
    final ranges = [
      {'key': 'ALL', 'label': 'All Time'},
      {'key': 'TODAY', 'label': 'Today'},
      {'key': 'WEEK', 'label': 'This Week'},
      {'key': 'MONTH', 'label': 'This Month'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search Invoice ID, Account Name, or Customer...",
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                filled: true,
                fillColor: AdminTheme.pearlWhite,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: ranges.map((r) {
              final isSelected = _dateRange == r['key'];
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(r['label']!),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _dateRange = r['key']!),
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
        ],
      ),
    );
  }

  Widget _buildBilledTransactionsList(List<Map<String, dynamic>> orders) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ord = orders[index];
        final id = (ord['id'] ?? ord['order_id'] ?? '-').toString();
        final method = (ord['payment_method'] ?? ord['method'] ?? 'Cash').toString();
        final amount = _parseAmount(ord['total_amount'] ?? ord['total']);
        final date = (ord['created_at'] ?? ord['date'] ?? 'Today').toString();
        final status = (ord['status'] ?? 'Completed').toString().toUpperCase();

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
                  color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "#$id",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdminTheme.royalBlue),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AdminTheme.royalBlue),
                              const SizedBox(width: 6),
                              Text(
                                "Credited to: $method",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text("Billed Date & Time: $date", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "NPR ${amount.toStringAsFixed(0)}",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AdminTheme.emeraldGreen),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AdminTheme.emeraldGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.emeraldGreen),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showInvoiceModal(context, ord),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminTheme.royalBlue,
                          side: const BorderSide(color: AdminTheme.royalBlue),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.receipt_rounded, size: 14),
                        label: const Text("RECEIPT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyStateCard(Map<String, dynamic>? account) {
    final String accName = account != null ? (account['name'] ?? 'Selected Account') : 'Selected Account';

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
          const Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            "No Billed Transactions Found for $accName",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
          ),
          const SizedBox(height: 6),
          const Text("No bill invoices were generated using this payment method in the selected timeframe.", style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  void _showInvoiceModal(BuildContext context, Map<String, dynamic> ord) {
    final id = (ord['id'] ?? ord['order_id'] ?? '-').toString();
    final method = (ord['payment_method'] ?? ord['method'] ?? 'Cash').toString();
    final amount = _parseAmount(ord['total_amount'] ?? ord['total']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Order Invoice #$id", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            _buildInvoiceRow("Invoice Number:", "#$id"),
            _buildInvoiceRow("Paid Payment Account:", method),
            _buildInvoiceRow("Total Billed Amount:", "NPR ${amount.toStringAsFixed(0)}"),
            _buildInvoiceRow("Payment Status:", "PAID / CREDITED"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminTheme.emeraldGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AdminTheme.emeraldGreen, size: 18),
                  SizedBox(width: 8),
                  Text("Bill revenue credited to account profile.", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
            child: const Text("CLOSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.darkNavy)),
        ],
      ),
    );
  }
}
