import 'package:flutter/material.dart';
import 'dart:async';
import '../../cart_manager.dart';
import '../theme.dart';
import 'digital_menu_screen.dart';
import 'bill_settlement_screen.dart';

class RunningOrderSummaryScreen extends StatefulWidget {
  final String tableId;
  const RunningOrderSummaryScreen({super.key, required this.tableId});

  @override
  State<RunningOrderSummaryScreen> createState() => _RunningOrderSummaryScreenState();
}

class _RunningOrderSummaryScreenState extends State<RunningOrderSummaryScreen> {
  Timer? _timer;
  String _elapsedStr = "0m";
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) => _updateElapsed());
    _updateElapsed();
  }

  void _updateElapsed() {
    final int tableIdInt = ShopManager.parseTableId(widget.tableId);
    final startTime = ShopManager.instance.tableStartTimes.value[tableIdInt];
    if (startTime != null) {
      final diff = DateTime.now().difference(startTime);
      setState(() {
        _elapsedStr = "${diff.inMinutes}m";
      });
    }
  }

  Future<void> _handleConfirmOrder() async {
    setState(() => _isConfirming = true);
    final int tableIdInt = ShopManager.parseTableId(widget.tableId);
    
    // We get the result map which might contain an error message
    final result = await ShopManager.instance.confirmTableOrderWithResult(tableIdInt);
    
    if (!mounted) return;
    setState(() => _isConfirming = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order sent to Kitchen successfully!"), 
          backgroundColor: WaiterProTheme.emeraldGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // SHOW THE REAL ERROR MESSAGE FROM THE SERVER
      String errorMsg = result['message'] ?? "Unknown connection error.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("ORDER FAILED: $errorMsg"), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: "RETRY", textColor: Colors.white, onPressed: _handleConfirmOrder),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int tableIdInt = ShopManager.parseTableId(widget.tableId);

    return Scaffold(
      appBar: AppBar(
        title: Text("Running Order: ${widget.tableId}", style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DigitalMenuScreen(tableId: widget.tableId)),
            ),
            icon: const Icon(Icons.add_circle_outline, color: WaiterProTheme.royalBlue),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          ShopManager.instance.tableOrders,
          ShopManager.instance.confirmedTableOrders,
        ]),
        builder: (context, _) {
          final newItems = ShopManager.instance.tableOrders.value[tableIdInt] ?? [];
          final confirmedItems = ShopManager.instance.confirmedTableOrders.value[tableIdInt] ?? [];
          
          double subtotal = 0;
          for (var item in [...newItems, ...confirmedItems]) {
            double price = double.tryParse(item.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
            subtotal += price * item.quantity;
          }

          if (newItems.isEmpty && confirmedItems.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _buildSessionHeader(newItems.length + confirmedItems.length),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (newItems.isNotEmpty) ...[
                      _buildSectionTitle("NEW ITEMS (DRAFT)"),
                      ...newItems.map((item) => _buildItemCard(item, isConfirmed: false)),
                      const SizedBox(height: 20),
                    ],
                    if (confirmedItems.isNotEmpty) ...[
                      _buildSectionTitle("IN PREPARATION"),
                      ...confirmedItems.map((item) => _buildItemCard(item, isConfirmed: true)),
                    ],
                  ],
                ),
              ),
              _buildBottomActions(subtotal, newItems.isNotEmpty),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No active orders for this table", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DigitalMenuScreen(tableId: widget.tableId)),
            ),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            child: const Text("START ORDERING"),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHeader(int totalItems) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: WaiterProTheme.royalBlue.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: WaiterProTheme.royalBlue),
          const SizedBox(width: 8),
          Text("Active for: $_elapsedStr", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text("$totalItems total items", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
    );
  }

  Widget _buildItemCard(CartItem item, {required bool isConfirmed}) {
    double price = double.tryParse(item.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: WaiterProTheme.softShadow,
        border: Border.all(color: isConfirmed ? WaiterProTheme.royalBlue.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(item.product.image, width: 45, height: 45, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("NPR ${price.toStringAsFixed(0)} each", style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("x${item.quantity}", style: const TextStyle(fontWeight: FontWeight.w900, color: WaiterProTheme.darkNavy, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isConfirmed ? WaiterProTheme.royalBlue : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isConfirmed ? "PREPARING" : "WAITING",
                  style: TextStyle(color: isConfirmed ? WaiterProTheme.royalBlue : Colors.orange, fontSize: 7, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (!isConfirmed) ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => _showDeleteConfirm(context, ShopManager.parseTableId(widget.tableId), item.product.title),
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildBottomActions(double subtotal, bool hasNewItems) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -4))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("RUNNING TOTAL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
              Text("NPR ${subtotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: WaiterProTheme.royalBlue)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (hasNewItems)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConfirming ? null : _handleConfirmOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5C00),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isConfirming 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("CONFIRM ORDER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => BillSettlementScreen(tableId: widget.tableId)),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: WaiterProTheme.emeraldGreen, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("SETTLE BILL", style: TextStyle(color: WaiterProTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                  ),
                ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DigitalMenuScreen(tableId: widget.tableId))),
                style: IconButton.styleFrom(
                  backgroundColor: WaiterProTheme.royalBlue.withOpacity(0.1),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add_shopping_cart, color: WaiterProTheme.royalBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, int tableId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Item?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to remove '$title' from the draft?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              ShopManager.instance.removeFromTableOrder(tableId, title);
              Navigator.pop(ctx);
            }, 
            child: const Text("REMOVE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
