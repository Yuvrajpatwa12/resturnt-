import 'package:flutter/material.dart';
import '../../cart_manager.dart';

class AdminTab extends StatefulWidget {
  const AdminTab({super.key});

  @override
  State<AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<AdminTab> {
  String _timeFilter = "Today";

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTimeFilter("Today"),
              _buildTimeFilter("Yesterday"),
              const Spacer(),
              const Text("STATS HUB", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 24),
          
          // --- SALES & REVENUE PROGRESS ---
          Row(
            children: [
              _buildSalesCard("Sales", "NPR 145,943", "+14%", Colors.orange),
              const SizedBox(width: 16),
              _buildRevenueTargetCard(),
            ],
          ),
          
          const SizedBox(height: 32),
          const Text("Peak Hours", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _buildPeakHoursChart(),

          const SizedBox(height: 32),
          Row(
            children: [
              _buildStatCard("Avg Prep Time", "12:45", Icons.timer, Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard("Staff Rating", "4.9/5", Icons.star, Colors.indigo),
            ],
          ),

          const SizedBox(height: 32),
          const Text("Urgent Deliveries", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _buildUrgentTablesList(),
          
          const SizedBox(height: 32),
          const Text("Monthly Performance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _buildMockCalendar(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPeakHoursChart() {
    final List<double> heights = [20, 40, 70, 90, 100, 80, 50, 30, 20];
    final List<String> labels = ["9AM", "11AM", "1PM", "3PM", "5PM", "7PM", "9PM", "11PM", "1AM"];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(heights.length, (i) {
              return Column(
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 500 + (i * 100)),
                    width: 25,
                    height: heights[i],
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFF5C00), const Color(0xFFFF5C00).withOpacity(0.3)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(labels[i], style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTargetCard() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            const Text("Revenue vs Target", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 15),
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 60, height: 60,
                  child: CircularProgressIndicator(
                    value: 0.82,
                    strokeWidth: 6,
                    color: Color(0xFFFF5C00),
                    backgroundColor: Color(0xFFF7F8FA),
                  ),
                ),
                const Text("82%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            const Text("Target: NPR 180K", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentTablesList() {
    return ValueListenableBuilder<Map<int, int>>(
      valueListenable: ShopManager.instance.tableCountdownTimers,
      builder: (context, timers, child) {
        final urgent = timers.entries.where((e) => e.value > 0 && e.value < 120).toList();
        if (urgent.isEmpty) {
          return const Center(child: Text("No urgent tables at the moment", style: TextStyle(color: Colors.grey, fontSize: 12)));
        }
        return Column(
          children: urgent.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.red, size: 18),
                const SizedBox(width: 12),
                Text("Table 1F-0${e.key % 100}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("${(e.value / 60).floor()}:${(e.value % 60).toString().padLeft(2, '0')} LEFT", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
              ],
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildTimeFilter(String label) {
    bool isSelected = _timeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _timeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSalesCard(String label, String value, String change, Color color) {
    bool isPositive = change.startsWith('+');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(change, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPositive ? Colors.orange : Colors.red)),
                const SizedBox(width: 4),
                Text("vs last week", style: TextStyle(fontSize: 8, color: Colors.grey[400])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockCalendar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"].map((d) => Text(d, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))).toList(),
          ),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 10, crossAxisSpacing: 10),
            itemCount: 31,
            itemBuilder: (context, index) {
              bool isHighlight = index == 8 || index == 9 || index == 10;
              return Center(
                child: Column(
                  children: [
                    Text("${index + 1}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    if (isHighlight)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFF5C00).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text("NPR ${800 + index}", style: const TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00))),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
