import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../admin_theme.dart';

class CustomerManagementScreen extends StatefulWidget {
  final String mode; // "Customer List", "Type List", "Third-Party Customers", "Card Terminal List"
  const CustomerManagementScreen({super.key, required this.mode});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  // --- DATA SOURCES ---
  final List<Map<String, dynamic>> _customers = [
    {'id': '1', 'name': 'Arbind Patel', 'phone': '9800000000', 'email': 'arbind@mail.com', 'type': 'VIP', 'points': 1250, 'total_spent': 15400, 'last_visit': '2 days ago'},
    {'id': '2', 'name': 'Sandhya Sharma', 'phone': '9811111111', 'email': 'sandhya@mail.com', 'type': 'Regular', 'points': 450, 'total_spent': 5200, 'last_visit': 'Today'},
    {'id': '3', 'name': 'Tech Solutions', 'phone': '01-4444444', 'email': 'info@tech.com', 'type': 'Corporate', 'points': 0, 'total_spent': 85000, 'last_visit': '1 week ago'},
    {'id': '4', 'name': 'Ram Kumar', 'phone': '9844444444', 'email': 'ram@mail.com', 'type': 'Regular', 'points': 120, 'total_spent': 1200, 'last_visit': '5 days ago'},
  ];

  final List<Map<String, dynamic>> _customerTypes = [
    {'name': 'Regular Customer', 'discount': 5, 'icon': Icons.person},
    {'name': 'QR Customer', 'discount': 0, 'icon': Icons.qr_code},
    {'name': 'Take Way', 'discount': 5, 'icon': Icons.shopping_bag},
    {'name': 'Third Party', 'discount': 0, 'icon': Icons.language},
    {'name': 'Walk In Customer', 'discount': 0, 'icon': Icons.directions_walk},
    {'name': 'Monthly Other', 'discount': 10, 'icon': Icons.calendar_month},
  ];

  final List<Map<String, dynamic>> _thirdPartyPlatforms = [
    {'name': 'Foodmandu', 'contact': 'Rajesh Hamal', 'phone': '9851000000', 'commission': 20.00, 'comm_type': '%', 'status': true, 'address': 'Kathmandu'},
    {'name': 'Pathao Food', 'contact': 'Sita Thapa', 'phone': '9841000000', 'commission': 50.00, 'comm_type': 'Rs', 'status': true, 'address': 'Lalitpur'},
    {'name': 'Bhoj Deals', 'contact': 'Ram Sah', 'phone': '9801000000', 'commission': 18.00, 'comm_type': '%', 'status': true, 'address': 'Dhaka'},
    {'name': 'Facebook/Meta', 'contact': 'Direct', 'phone': 'N/A', 'commission': 0.00, 'comm_type': '%', 'status': true, 'address': 'Online'},
  ];

  final List<Map<String, dynamic>> _terminals = [
    {
      'id': 'QR-101',
      'name': 'Fonepay QR',
      'category': 'QR Merchant',
      'model': 'Dynamic/Static QR',
      'status': 'Online',
      'today_total': 8450.00,
      'customer_count': 12,
      'last_settle': 'Today 11:30 AM',
      'icon': Icons.qr_code_scanner
    },
    {
      'id': 'ES-502',
      'name': 'e-Sewa Wallet',
      'category': 'Digital Wallet',
      'model': 'Merchant API',
      'status': 'Online',
      'today_total': 3200.00,
      'customer_count': 5,
      'last_settle': 'Today 10:00 AM',
      'icon': Icons.account_balance_wallet_outlined
    },
    {
      'id': 'T-1001',
      'name': 'Nabil Bank POS',
      'category': 'Card Terminal',
      'model': 'Pax A920 (Android)',
      'status': 'Online',
      'today_total': 12450.00,
      'customer_count': 8,
      'last_settle': 'Yesterday 10:30 PM',
      'icon': Icons.credit_card
    },
    {
      'id': 'KH-201',
      'name': 'Khalti Payment',
      'category': 'Digital Wallet',
      'model': 'SDK Integration',
      'status': 'Online',
      'today_total': 1500.00,
      'customer_count': 3,
      'last_settle': 'Today 09:00 AM',
      'icon': Icons.wallet_membership_outlined
    },
    {
      'id': 'CASH-01',
      'name': 'Main Counter Cash',
      'category': 'Cash Account',
      'model': 'Physical Drawer',
      'status': 'Online',
      'today_total': 25600.00,
      'customer_count': 45,
      'last_settle': 'Today 08:30 AM',
      'icon': Icons.payments_outlined
    },
  ];

  String _searchQuery = "";
  int _rowsPerPage = 10;
  String _selectedTier = "All Tiers";
  String _paymentCategoryFilter = "ALL";

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSummaryStats(),
          const SizedBox(height: 32),
          _buildContextualView(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final headerContent = [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(_getModeIcon(), color: AdminTheme.royalBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.mode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy), overflow: TextOverflow.ellipsis),
                  Text(_getModeSubtitle(), style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ];

          final addButton = ElevatedButton.icon(
            onPressed: () => _handleAddNew(),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text("ADD ${_getModeBtnLabel()}", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.royalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: headerContent),
                const SizedBox(height: 16),
                addButton,
              ],
            );
          }
          return Row(children: [...headerContent, const SizedBox(width: 16), addButton]);
        },
      ),
    );
  }

  Widget _buildSummaryStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _getModeStats(),
      ),
    );
  }

  List<Widget> _getModeStats() {
    switch (widget.mode) {
      case "Customer List":
        return [
          _buildStatCard("Total Customers", _customers.length.toString(), Icons.people, Colors.blue),
          _buildStatCard("VIP Members", _customers.where((c) => c['type'] == 'VIP').length.toString(), Icons.star, Colors.orange),
          _buildStatCard("Total Points", "84,500", Icons.card_giftcard, Colors.green),
        ];
      case "Customer Type List":
        return [
          _buildStatCard("Defined Types", _customerTypes.length.toString(), Icons.category, Colors.purple),
          _buildStatCard("Active Discounts", "4 Types", Icons.percent, Colors.red),
        ];
      case "Third-Party Customers":
        return [
          _buildStatCard("Integrated Apps", _thirdPartyPlatforms.length.toString(), Icons.app_shortcut, Colors.indigo),
          _buildStatCard("Active Status", "4 Online", Icons.check_circle, Colors.green),
        ];
      case "Card Terminal List":
        return [
          _buildStatCard("Active Terminals", _terminals.length.toString(), Icons.terminal, Colors.blue),
          _buildStatCard("Today's Digital", "Rs. 45,600", Icons.account_balance_wallet, Colors.green),
        ];
      default:
        return [];
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 2),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualView() {
    switch (widget.mode) {
      case "Customer List":
        return _buildCustomerList();
      case "Customer Type List":
        return _buildTypeList();
      case "Third-Party Customers":
        return _buildThirdPartyList();
      case "Card Terminal List":
        return _buildTerminalList();
      default:
        return const Center(child: Text("Feature under development..."));
    }
  }

  // --- 1. CUSTOMER LIST VIEW ---
  Widget _buildCustomerList() {
    final filteredList = _customers.where((c) {
      final matchesSearch = c['name'].toLowerCase().contains(_searchQuery.toLowerCase()) || c['phone'].contains(_searchQuery);
      final matchesTier = _selectedTier == "All Tiers" || c['type'].toString().toUpperCase() == _selectedTier.toUpperCase();
      return matchesSearch && matchesTier;
    }).toList();

    Set<String> tiers = {"All Tiers", "Regular", "VIP", "Corporate"};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tiers.map((t) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildTierChip(t),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              horizontalMargin: 0,
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
              columns: const [
                DataColumn(label: Text("CUSTOMER NAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text("CONTACT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text("TIER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text("POINTS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text("TOTAL SPENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text("ACTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: filteredList.take(_rowsPerPage).map((c) => DataRow(
                    cells: [
                      DataCell(Text(c['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['phone'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(c['email'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      )),
                      DataCell(_buildStatusTag(c['type'], _getTierColor(c['type']))),
                      DataCell(Text(c['points'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.royalBlue))),
                      DataCell(Text("Rs. ${c['total_spent']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Row(
                        children: [
                          _buildMiniActionBtn(Icons.history, Colors.cyan, () {}),
                          const SizedBox(width: 8),
                          _buildMiniActionBtn(Icons.edit_outlined, AdminTheme.royalBlue, () {}),
                        ],
                      )),
                    ],
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. CUSTOMER TYPE LIST VIEW ---
  Widget _buildTypeList() {
    final filteredTypes = _customerTypes.where((t) {
      return t['name'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Display ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    DropdownButton<int>(
                      value: _rowsPerPage,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      style: const TextStyle(fontSize: 12, color: AdminTheme.darkNavy, fontWeight: FontWeight.bold),
                      items: [5, 10, 15, 20, 25, 50, 100].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text("$value"),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) setState(() => _rowsPerPage = newValue);
                      },
                    ),
                    const Text(" records per page", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildMiniExportBtn("CSV"),
                  _buildMiniExportBtn("Pdf"),
                  _buildMiniExportBtn("Print"),
                ],
              ),
              Container(
                width: 250,
                height: 40,
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey, size: 18),
                    hintText: "Search type name...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 24,
              headingRowHeight: 45,
              dataRowMinHeight: 55,
              dataRowMaxHeight: 55,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              columns: const [
                DataColumn(label: Text("SN", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                DataColumn(label: Text("Customer Type Name", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                DataColumn(label: Text("Discount (%)", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
              ],
              rows: List.generate(
                filteredTypes.length > _rowsPerPage ? _rowsPerPage : filteredTypes.length,
                (index) {
                  final type = filteredTypes[index];
                  return DataRow(
                    cells: [
                      DataCell(Text("${index + 1}", style: const TextStyle(color: Colors.grey, fontSize: 13))),
                      DataCell(Text(type['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      DataCell(Text("${type['discount']}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))),
                      DataCell(Row(
                        children: [
                          _buildMiniActionBtn(Icons.edit_outlined, Colors.cyan, () {}),
                          const SizedBox(width: 8),
                          _buildMiniActionBtn(Icons.delete_outline_rounded, Colors.redAccent, () {}),
                        ],
                      )),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildPaginationBtn("Previous", false),
              _buildPaginationBtn("1", true),
              _buildPaginationBtn("Next", false),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. THIRD PARTY LIST VIEW ---
  Widget _buildThirdPartyList() {
    final filteredPlatforms = _thirdPartyPlatforms.where((p) {
      return p['name'].toLowerCase().contains(_searchQuery.toLowerCase()) || (p['address'] ?? "").toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AdminTheme.softShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("Display ", style: TextStyle(fontSize: 11, color: Colors.black87)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                    child: DropdownButton<int>(
                      value: _rowsPerPage,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      items: [10, 25, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text("$v", style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (v) => setState(() => _rowsPerPage = v!),
                    ),
                  ),
                  const Text(" records per page", style: TextStyle(fontSize: 11, color: Colors.black87)),
                ],
              ),
              Row(
                children: [
                  _buildMiniExportBtn("CSV"),
                  _buildMiniExportBtn("Pdf"),
                  _buildMiniExportBtn("Print"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              horizontalMargin: 12,
              columnSpacing: 20,
              headingRowHeight: 45,
              dataRowMinHeight: 50,
              dataRowMaxHeight: 50,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              border: TableBorder.all(color: Colors.grey.shade200, width: 0.5),
              columns: const [
                DataColumn(label: Text("SN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Third Party Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Commission", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Contact Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
              rows: List.generate(
                filteredPlatforms.length > _rowsPerPage ? _rowsPerPage : filteredPlatforms.length,
                (index) {
                  final p = filteredPlatforms[index];
                  return DataRow(
                    cells: [
                      DataCell(Text("${index + 1}", style: const TextStyle(fontSize: 12))),
                      DataCell(Text(p['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                      DataCell(Text("${p['commission']} ${p['comm_type']}", style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold))),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['contact'] ?? "", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(p['phone'] ?? "", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      )),
                      DataCell(Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: p['status'],
                          onChanged: (v) => setState(() => p['status'] = v),
                          activeColor: Colors.green,
                        ),
                      )),
                      DataCell(Row(
                        children: [
                          _buildMiniActionBtn(Icons.edit, Colors.cyan, () {}),
                          const SizedBox(width: 6),
                          _buildMiniActionBtn(Icons.delete, Colors.redAccent, () {}),
                        ],
                      )),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. TERMINAL LIST VIEW ---
  Widget _buildTerminalList() {
    final filteredTerminals = _terminals.where((t) {
      final matchesSearch = t['name'].toLowerCase().contains(_searchQuery.toLowerCase()) || t['id'].toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _paymentCategoryFilter == "ALL" || t['category'].toUpperCase().contains(_paymentCategoryFilter);
      return matchesSearch && matchesCat;
    }).toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AdminTheme.royalBlue.withValues(alpha: 0.05), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: AdminTheme.royalBlue, size: 20),
                  const SizedBox(width: 12),
                  const Text("TERMINAL ENGAGEMENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: AdminTheme.darkNavy)),
                  const Spacer(),
                  _buildSearchField(),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildEngagementCard("ALL", _terminals.length, Icons.groups_outlined, Colors.grey, filterKey: "ALL"),
                  _buildEngagementCard("QR", _terminals.where((t) => t['category'] == 'QR Merchant').length, Icons.qr_code, Colors.green, filterKey: "QR"),
                  _buildEngagementCard("POS", _terminals.where((t) => t['category'] == 'Card Terminal').length, Icons.credit_card, Colors.blue, filterKey: "CARD"),
                ],
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.5,
          ),
          itemCount: filteredTerminals.length,
          itemBuilder: (context, index) {
            final t = filteredTerminals[index];
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(t['icon'], color: AdminTheme.royalBlue),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      _buildStatusTag(t['status'], Colors.green),
                    ],
                  ),
                  const Spacer(),
                  Text("Total Today: Rs. ${t['today_total']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminTheme.royalBlue)),
                  Text("Transactions: ${t['customer_count']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEngagementCard(String label, int count, IconData icon, Color color, {required String filterKey}) {
    bool isSelected = _paymentCategoryFilter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentCategoryFilter = filterKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey.shade100, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text("$count", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: const InputDecoration(hintText: "Search...", border: InputBorder.none, icon: Icon(Icons.search, size: 16, color: Colors.grey)),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildTierChip(String label) {
    bool isSelected = _selectedTier == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) => setState(() => _selectedTier = label),
      selectedColor: AdminTheme.royalBlue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStatusTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMiniExportBtn(String label) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: OutlinedButton(onPressed: () {}, child: Text(label, style: const TextStyle(fontSize: 11))),
    );
  }

  Widget _buildPaginationBtn(String label, bool active) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(backgroundColor: active ? AdminTheme.royalBlue : Colors.white, foregroundColor: active ? Colors.white : Colors.black87),
        child: Text(label),
      ),
    );
  }

  Widget _buildMiniActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  IconData _getModeIcon() {
    switch (widget.mode) {
      case "Customer List": return Icons.people;
      case "Customer Type List": return Icons.category;
      case "Third-Party Customers": return Icons.language;
      case "Card Terminal List": return Icons.credit_card;
      default: return Icons.settings;
    }
  }

  String _getModeSubtitle() {
    return "Manage and track ${widget.mode.toLowerCase()} records.";
  }

  String _getModeBtnLabel() {
    return widget.mode.replaceAll(" List", "").toUpperCase();
  }

  void _handleAddNew() {}
  void _showToast(String msg) {}
  Color _getTierColor(String tier) {
    if (tier == 'VIP') return Colors.orange;
    if (tier == 'Corporate') return Colors.purple;
    return Colors.blue;
  }

  void _openCustomerDialog({Map<String, dynamic>? existingCustomer}) {}
  void _openCustomerTypeDialog({Map<String, dynamic>? existingType}) {}
  void _deleteCustomerType(Map<String, dynamic> type) {}
  void _openThirdPartyDialog({Map<String, dynamic>? existingPlatform}) {}
  void _deleteThirdParty(Map<String, dynamic> platform) {}
}
