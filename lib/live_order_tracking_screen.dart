import 'package:flutter/material.dart';
import 'battleground_creation_page.dart';
import 'cart_manager.dart';
import 'services/api_service.dart';
import 'services/tenant_service.dart';
import 'dart:async';
import 'homepage.dart';
import 'widgets/waiter_assistance_modal.dart';
import 'services/feature_flags.dart';

class LiveOrderTrackingScreen extends StatefulWidget {
  final int orderId;
  final String? displayOrderNumber;
  const LiveOrderTrackingScreen({
    super.key,
    required this.orderId,
    this.displayOrderNumber,
  });

  @override
  State<LiveOrderTrackingScreen> createState() =>
      _LiveOrderTrackingScreenState();
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
    _statusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) => _fetchStatus(),
    );
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final tenantId = TenantService().currentTenant.value?.id.trim() ?? '';
      if (tenantId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        _statusTimer?.cancel();
        return;
      }
      final status = await ApiService.fetchOrderStatus(
        widget.orderId,
        tenantId: tenantId,
      );
      if (TenantService().currentTenant.value?.id != tenantId) return;
      if (status != null && mounted) {
        setState(() {
          _currentStatus = status;
          _isLoading = false;
        });
        if (status == 'Completed' || status == 'Cancelled') {
          _statusTimer?.cancel();
        }
      } else if (mounted) {
        // If status is null (order not found yet), stop loading but keep current status
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Order Tracking",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            ShopManager.instance.currentTabIndex.value = 4; // Set Profile Tab
            // Push HomePage and clear routes to avoid Splash Screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomePage()),
              (route) => false,
            );
          },
        ),
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
                  if (_canShowBattleground) ...[
                    const SizedBox(height: 24),
                    _buildBattlegroundCard(),
                  ],
                  const SizedBox(height: 40),
                  _buildOrderSummary(),
                  const SizedBox(height: 32),
                  _buildHelpCard(),
                ],
              ),
            ),
    );
  }

  bool get _canShowBattleground {
    return FeatureFlags.gamesEnabled;
  }

  Widget _buildBattlegroundCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_esports_rounded, color: Color(0xFFFF5C00)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you bored? 😴',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  'Challenge your table to a Battleground.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BattlegroundCreationPage(),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5C00),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _getStatusColor().withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(_getStatusIcon(), size: 48, color: _getStatusColor()),
          const SizedBox(height: 16),
          Text(
            _getStatusTitle(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _getStatusColor(),
            ),
          ),
          Text(
            "ORDER ID: #${widget.displayOrderNumber ?? widget.orderId}",
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1,
            ),
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
    Color color = isDone
        ? Colors.green
        : (isActive ? Theme.of(context).primaryColor : Colors.grey[300]!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : color,
                shape: BoxShape.circle,
                border: isActive ? Border.all(color: color, width: 6) : null,
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (stepIndex != 5)
              Container(
                width: 2,
                height: 40,
                color: isDone ? Colors.green : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isActive ? Colors.black : Colors.grey[600],
                ),
              ),
              Text(
                sub,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  int _getStepIndex(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return 0;
      case 'approved':
        return 1;
      case 'preparing':
        return 2;
      case 'ready':
        return 3;
      case 'onway':
      case 'on way':
        return 4;
      case 'completed':
      case 'served':
        return 5;
      default:
        return 0;
    }
  }

  String _getStatusTitle() {
    switch (_currentStatus.trim().toLowerCase()) {
      case 'pending':
        return "Pending Approval";
      case 'approved':
        return "Accepted";
      case 'preparing':
        return "In the Kitchen";
      case 'ready':
        return "Ready for Pickup";
      case 'onway':
      case 'on way':
        return "Bringing to Table";
      case 'completed':
      case 'served':
        return "Served";
      default:
        return "Processing";
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus.trim().toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready':
        return Colors.green;
      case 'onway':
      case 'on way':
        return const Color(0xFF6236FF);
      case 'completed':
      case 'served':
        return Colors.teal;
      default:
        return const Color(0xFFFF5C00);
    }
  }

  IconData _getStatusIcon() {
    switch (_currentStatus.trim().toLowerCase()) {
      case 'pending':
        return Icons.timer_outlined;
      case 'preparing':
        return Icons.restaurant;
      case 'onway':
      case 'on way':
        return Icons.directions_run;
      case 'completed':
      case 'served':
        return Icons.check_circle;
      default:
        return Icons.local_fire_department;
    }
  }

  Widget _buildOrderSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Order Tracking Info",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            "Tracking is live for Order #${widget.displayOrderNumber ?? widget.orderId}. Your order is currently being processed by our staff.",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return GestureDetector(
      onTap: () {
        WaiterAssistanceModal.show(context);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF002D62),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF002D62).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Need help?",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Ask our waiter for assistance ->",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
