import 'package:flutter/material.dart';
import 'staff_final_receipt_page.dart';

class HistoricalBillDetailsPage extends StatelessWidget {
  final Map<String, dynamic> bill;
  const HistoricalBillDetailsPage({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final List items = bill['items'] as List;
    final bool isActive = bill['status'] == 'Active';
    final bool isBilled = bill['status'] == 'Billed';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Hero(
          tag: "order_id_${bill['id']}",
          child: Material(
            color: Colors.transparent,
            child: Text(
              "Order #${bill['id']}", 
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18)
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- 1. STATUS & META HUB ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFFF5C00).withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    bill['status'].toUpperCase(),
                    style: TextStyle(
                      color: isActive ? const Color(0xFFFF5C00) : Colors.green,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetaInfo("TABLE", bill['table']),
                    _buildMetaInfo("DATE", bill['date']),
                    _buildMetaInfo("TIME", bill['time']),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(24, 30, 24, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "ORDER BREAKDOWN",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey),
              ),
            ),
          ),

          // --- 2. ITEM LIST ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                        child: Text(
                          "${item['qty']}x", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFFF5C00))
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          item['name'], 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                        ),
                      ),
                      Text(
                        item['price'], 
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // --- 3. FINANCIAL SUMMARY ---
          Container(
            padding: const EdgeInsets.all(30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL BILL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey)),
                    Hero(
                      tag: "order_total_${bill['id']}",
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          bill['total'], 
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                
                if (isActive)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // For mock demo, we'll try to use the existing receipt page
                        // Since receipt page currently uses Table ID orders, 
                        // we'll just show the receipt for Table 7 (mock ID 146) 
                        // or similar logic. 
                        int tableNum = int.tryParse(bill['table'].replaceAll('Table ', '')) ?? 1;
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => StaffFinalReceiptPage(tableId: tableNum))
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C00),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 10,
                        shadowColor: const Color(0xFFFF5C00).withValues(alpha: 0.3),
                      ),
                      child: const Text("CREATE FINAL BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  )
                else if (isBilled)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Payment recorded! Order archived.")),
                        );
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("MARK AS PAID", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                
                const SizedBox(height: 10),
                const Text("Handled by Server: Catherine", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
