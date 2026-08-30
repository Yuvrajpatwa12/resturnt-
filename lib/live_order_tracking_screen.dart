import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'services/api_service.dart';
import 'dart:async';

class LiveOrderTrackingScreen extends StatefulWidget {
  final int orderId;
  const LiveOrderTrackingScreen({super.key, required this.orderId});

  @override
  State<LiveOrderTrackingScreen> createState() => _LiveOrderTrackingScreenState();
}

class _LiveOrderTrackingScreenState extends State<LiveOrderTrackingScreen> {
  String _currentStatus = 'Pending';
  Timer? _statusTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchStatus());
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final status = await ApiService.fetchOrderStatus(widget.orderId);
    if (status != null && mounted) {
      setState(() {
        _currentStatus = status;
        _isLoading = false;
      });
      if (status == 'Completed' || status == 'Cancelled') {
        _statusTimer?.cancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Order Tracking", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildStatusBanner(),
                const SizedBox(height: 32),
                _buildStepper(),
                const SizedBox(height: 40),
                _buildOrderSummary(),
                const SizedBox(height: 32),
                _buildHelpCard(),
              ],
            ),
          ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _getStatusColor().withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(_getStatusIcon(), size: 48, color: _getStatusColor()),
          const SizedBox(height: 16),
          Text(
            _getStatusTitle(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _getStatusColor()),
          ),
          Text(
            "ORDER ID: #${widget.orderId}",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Column(
      children: [
        _buildStepItem("Order Placed", "Waiting for waiter to approve", 0),
        _buildStepItem("Approved", "Waiter accepted your request", 1),
        _buildStepItem("Preparing", "Chef is cooking your meal", 2),
        _buildStepItem("Ready", "Your food is ready in kitchen", 3),
        _buildStepItem("On the Way", "Waiter is bringing your food", 4),
        _buildStepItem("Served", "Arrived at your table!", 5),
      ],
    );
  }

  Widget _buildStepItem(String title, String sub, int stepIndex) {
    int currentStepIndex = _getStepIndex(_currentStatus);
    bool isDone = currentStepIndex > stepIndex;
    bool isActive = currentStepIndex == stepIndex;
    Color color = isDone ? Colors.green : (isActive ? const Color(0xFFFF5C00) : Colors.grey[300]!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : color,
                shape: BoxShape.circle,
                border: isActive ? Border.all(color: color, width: 6) : null,
              ),
              child: isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            if (stepIndex != 5)
              Container(width: 2, height: 40, color: isDone ? Colors.green : Colors.grey[200]),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isActive ? Colors.black : Colors.grey[600])),
              Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  int _getStepIndex(String status) {
    switch (status) {
      case 'Pending': return 0;
      case 'Approved': return 1;
      case 'Preparing': return 2;
      case 'Ready': return 3;
      case 'OnWay': return 4;
      case 'Completed': return 5;
      default: return 0;
    }
  }

  String _getStatusTitle() {
    switch (_currentStatus) {
      case 'Pending': return "Pending Approval";
      case 'Approved': return "Accepted";
      case 'Preparing': return "In the Kitchen";
      case 'Ready': return "Ready for Pickup";
      case 'OnWay': return "Bringing to Table";
      case 'Completed': return "Served";
      default: return "Processing";
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case 'Pending': return Colors.orange;
      case 'Preparing': return Colors.blue;
      case 'OnWay': return const Color(0xFF6236FF);
      case 'Completed': return Colors.green;
      default: return const Color(0xFFFF5C00);
    }
  }

  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case 'Pending': return Icons.timer_outlined;
      case 'Preparing': return Icons.restaurant;
      case 'OnWay': return Icons.directions_run;
      case 'Completed': return Icons.check_circle;
      default: return Icons.local_fire_department;
    }
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Order Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          const Center(child: Text("Item list is being loaded from database...", style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF002D62), borderRadius: BorderRadius.circular(20)),
      child: const Row(
        children: [
          Icon(Icons.support_agent, color: Colors.white, size: 24),
          SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Need help?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("Ask our waiter for assistance.", style: TextStyle(color: Colors.white70, fontSize: 11))])),
        ],
      ),
    );
  }
}
