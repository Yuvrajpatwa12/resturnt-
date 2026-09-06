import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../pages/historical_bill_details_page.dart';

class BillsTab extends StatefulWidget {
  const BillsTab({super.key});

  @override
  State<BillsTab> createState() => _BillsTabState();
}

class _BillsTabState extends State<BillsTab> {
  String _currentFilter = "All";
  String _searchQuery = "";

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) return "TODAY";
    if (checkDate == yesterday) return "YESTERDAY";
    return "PREVIOUS SESSIONS";
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.allHistoricalBills,
      builder: (context, bills, child) {
        // Filter bills based on status and search query
        final filteredBills = bills.where((bill) {
          final matchesStatus = _currentFilter == "All" || bill['status'] == _currentFilter;
          final matchesSearch = bill['id'].toString().contains(_searchQuery) || 
                                bill['table'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesStatus && matchesSearch;
        }).toList();

        // Grouping bills by date
        Map<String, List<Map<String, dynamic>>> groupedBills = {};
        for (var bill in filteredBills) {
          DateTime ts = bill['timestamp'] as DateTime;
          String label = _getDateLabel(ts);
          if (!groupedBills.containsKey(label)) {
            groupedBills[label] = [];
          }
          groupedBills[label]!.add(bill);
        }

        final List<String> groupOrder = ["TODAY", "YESTERDAY", "PREVIOUS SESSIONS"];

        return Column(
          children: [
            // --- SEARCH BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search Order ID or Table...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            // --- STATUS FILTERS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  _buildBillStatusFilter("All"),
                  _buildBillStatusFilter("Active"),
                  _buildBillStatusFilter("Billed"),
                ],
              ),
            ),
            
            Expanded(
              child: filteredBills.isEmpty 
                ? const Center(child: Text("No orders found matching criteria", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: groupOrder.fold<int>(0, (sum, label) => sum + (groupedBills[label]?.isNotEmpty == true ? (groupedBills[label]!.length + 1) : 0)),
                    itemBuilder: (context, index) {
                      int currentIdx = 0;
                      for (var label in groupOrder) {
                        final items = groupedBills[label];
                        if (items == null || items.isEmpty) continue;

                        if (currentIdx == index) {
                          return _buildSectionHeader(label);
                        }
                        currentIdx++;

                        if (index < currentIdx + items.length) {
                          final bill = items[index - currentIdx];
                          return _buildBillCard(context, bill);
                        }
                        currentIdx += items.length;
                      }
                      return const SizedBox.shrink();
                    },
                  ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String label) {
    bool isToday = label == "TODAY";
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: isToday ? const Color(0xFFFF5C00) : Colors.grey[400],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Colors.grey[200])),
        ],
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, Map<String, dynamic> bill) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
              HistoricalBillDetailsPage(bill: bill),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: "order_id_${bill['id']}",
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            "Order #${bill['id']}", 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(bill['time'], style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(bill['table'], style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: (bill['items'] as List).take(2).map((item) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        item['name'], 
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Hero(
                  tag: "order_total_${bill['id']}",
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      bill['total'], 
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFFF5C00))
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bill['status'] == 'Active' ? const Color(0xFFFF5C00).withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    bill['status'].toUpperCase(),
                    style: TextStyle(
                      fontSize: 9, 
                      fontWeight: FontWeight.w900, 
                      color: bill['status'] == 'Active' ? const Color(0xFFFF5C00) : Colors.green
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillStatusFilter(String label) {
    bool isSelected = _currentFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5C00) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[200]!),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
