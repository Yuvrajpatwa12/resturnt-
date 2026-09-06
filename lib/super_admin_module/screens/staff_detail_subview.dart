import 'package:flutter/material.dart';
import '../styles.dart';

class StaffDetailSubview extends StatelessWidget {
  final Map<String, dynamic> staff;
  final VoidCallback onBack;

  const StaffDetailSubview({super.key, required this.staff, required this.onBack});

  @override
  Widget build(BuildContext context) {
    bool isKitchen = staff['role'].contains('Chef') || staff['role'].contains('Kitchen');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildPerformanceMetrics(isKitchen),
          const SizedBox(height: 32),
          _buildSpecializedInsights(isKitchen),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildActivityTable(context, isKitchen)),
              const SizedBox(width: 32),
              Expanded(child: _buildShiftLog()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final String name = staff['name'] ?? 'Unknown';
    final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Row(
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 30,
          backgroundColor: SAMStyles.royalBlue.withValues(alpha: 0.1),
          child: Text(firstLetter, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: SAMStyles.royalBlue)),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              Text("${staff['role']} • Staff ID: #ST-${name.length}09", style: const TextStyle(color: SAMStyles.textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    bool isOnline = staff['status'] == 'Online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: isOnline ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Text(
            isOnline ? "ACTIVE NOW" : "OFFLINE",
            style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(bool isKitchen) {
    return Row(
      children: [
        _buildMetricCard(isKitchen ? "Items Prepped" : "Orders Taken", "42", isKitchen ? Icons.restaurant : Icons.receipt_long, SAMStyles.royalBlue),
        const SizedBox(width: 24),
        _buildMetricCard(isKitchen ? "Avg. Cook Time" : "Avg. Response", "12m 40s", Icons.timer_outlined, Colors.orange),
        const SizedBox(width: 24),
        _buildMetricCard(isKitchen ? "Station Load" : "Active Tables", isKitchen ? "Medium" : "6 Tables", Icons.grid_view, Colors.blue),
        const SizedBox(width: 24),
        _buildMetricCard(isKitchen ? "Prep Efficiency" : "REVENUE GEN.", isKitchen ? "94%" : "NPR 18.2K", Icons.trending_up, SAMStyles.emeraldGreen),
      ],
    );
  }

  Widget _buildMetricCard(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: SAMStyles.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecializedInsights(bool isKitchen) {
    final items = isKitchen 
      ? [
          {'name': 'Chicken Momo', 'qty': 120, 'percent': 0.9},
          {'name': 'Buff Steam Momo', 'qty': 85, 'percent': 0.7},
          {'name': 'Veg Burger', 'qty': 45, 'percent': 0.4},
        ]
      : [
          {'name': 'Masala Tea', 'qty': 45, 'percent': 0.8},
          {'name': 'Chicken Momo', 'qty': 32, 'percent': 0.6},
          {'name': 'Iced Chiya', 'qty': 18, 'percent': 0.4},
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isKitchen ? "High Volume Prepared Items" : "Most Sold Items (Performance)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
          child: Row(
            children: items.map((item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: item == items.last ? 0 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text("${item['qty']} units", style: TextStyle(color: isKitchen ? Colors.orange : SAMStyles.royalBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: item['percent'] as double,
                      backgroundColor: (isKitchen ? Colors.orange : SAMStyles.royalBlue).withValues(alpha: 0.1),
                      color: isKitchen ? Colors.orange : SAMStyles.royalBlue,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTable(BuildContext context, bool isKitchen) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isKitchen ? "Kitchen Prep History" : "Waiter Order History", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SingleChildScrollView(
            child: DataTable(
              columns: [
                const DataColumn(label: Text("TICKET ID")),
                DataColumn(label: Text(isKitchen ? "STATION" : "TABLE")),
                const DataColumn(label: Text("TIME")),
                DataColumn(label: Text(isKitchen ? "PREP TIME" : "RESPONSE")),
                const DataColumn(label: Text("ACTION")),
              ],
              rows: List.generate(3, (index) => DataRow(cells: [
                DataCell(Text("#TKT-992$index", style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(isKitchen ? "Mains Dept." : "T-10$index")),
                DataCell(Text("12:${30 + index} PM")),
                DataCell(Text("${8 + index}m", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                DataCell(TextButton(
                  onPressed: () => _showTicketDetails(context, "#TKT-992$index"), 
                  child: const Text("DETAILS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SAMStyles.royalBlue)),
                )),
              ])),
            ),
          ),
        ],
      ),
    );
  }

  void _showTicketDetails(BuildContext context, String ticketId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Ticket Inspector: $ticketId"),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTicketItem("Chicken Steam Momo", "2", "NPR 900"),
              _buildTicketItem("Masala Chiya", "3", "NPR 180"),
              _buildTicketItem("Veg Burger", "1", "NPR 350"),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Total Transaction", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("NPR 1,430", style: TextStyle(fontWeight: FontWeight.w900, color: SAMStyles.royalBlue, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketItem(String name, String qty, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text("x$qty", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text(price, style: const TextStyle(fontSize: 13, color: SAMStyles.textGrey)),
        ],
      ),
    );
  }

  Widget _buildShiftLog() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Attendance Records", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildSessionItem("Shift Start", "08:00 AM", Icons.login, Colors.green),
          _buildSessionItem("Meal Break", "01:30 PM", Icons.coffee, Colors.orange),
          _buildSessionItem("Shift End", "05:00 PM", Icons.logout, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSessionItem(String action, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text(time, style: const TextStyle(color: SAMStyles.textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
