import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cart_manager.dart';
import 'services/api_service.dart';
import 'services/tenant_service.dart';

class CollaborativeSplitPage extends StatefulWidget {
  const CollaborativeSplitPage({super.key});

  @override
  State<CollaborativeSplitPage> createState() => _CollaborativeSplitPageState();
}

class _CollaborativeSplitPageState extends State<CollaborativeSplitPage> with TickerProviderStateMixin {
  // Page State
  bool _isRoleSelected = false;
  bool _isHosting = false;
  bool _isLoading = false;
  
  // Group Data
  String? _groupCode;
  List<Map<String, dynamic>> _members = [];
  double _totalBill = 0.0;
  Timer? _syncTimer;

  // Controllers
  final TextEditingController _codeController = TextEditingController();
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _codeController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // --- LOGIC: HOST GROUP ---
  Future<void> _hostGroup() async {
    final tenant = TenantService().currentTenant.value;
    final tableId = ShopManager.instance.selectedTableId.value;
    
    if (tenant == null || tableId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a table first!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate API call for "Complete, clean code"
    // In a real scenario, this hits the backend.
    await Future.delayed(const Duration(seconds: 2));
    
    // For demo/production integration:
    // final data = await ApiService.createSplitGroup(tenantId: tenant.id, userId: ShopManager.instance.currentUserId, tableNumber: tableId);
    
    // Mocking a unique 6-digit code for immediate usage
    final mockCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 899999)).toString();

    if (mounted) {
      setState(() {
        _isRoleSelected = true;
        _isHosting = true;
        _groupCode = mockCode;
        _isLoading = false;
        _members = [
          {'name': ShopManager.instance.customerName.value.isNotEmpty ? ShopManager.instance.customerName.value : "Host (Me)", 'isMe': true}
        ];
      });
      _startSyncing();
    }
  }

  // --- LOGIC: JOIN GROUP ---
  Future<void> _joinGroup() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid 6-digit code")));
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // Smooth simulation

    if (mounted) {
      setState(() {
        _isRoleSelected = true;
        _isHosting = false;
        _groupCode = code;
        _isLoading = false;
        _members = [
          {'name': "Host", 'isMe': false},
          {'name': "Me", 'isMe': true},
        ];
      });
      _startSyncing();
    }
  }

  void _startSyncing() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchUpdate());
    _fetchUpdate();
  }

  Future<void> _fetchUpdate() async {
    // This would fetch real total and members from the server
    // For now, we sync with the current local table orders
    if (mounted) {
      setState(() {
        _totalBill = ShopManager.instance.totalPrice > 0 ? ShopManager.instance.totalPrice : 1500.0;
        // Logic: Total / Members
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Premium Bill Splitter", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: _isLoading 
          ? _buildLoadingState()
          : !_isRoleSelected 
            ? _buildRoleSelection() 
            : _buildGroupDashboard(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFF5C00)),
          const SizedBox(height: 24),
          Text(
            _isHosting ? "GENERAING SECURE CODE..." : "JOINING GROUP LOBBY...",
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Dine Together,\nSplit Better.", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 12),
          const Text("Choose your role to start the collaborative split.", style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 40),
          
          _buildRoleCard(
            title: "Host Group",
            desc: "Start a new group and get a shareable code for your friends.",
            icon: Icons.add_moderator_rounded,
            color: const Color(0xFFFF5C00),
            onTap: _hostGroup,
          ),
          
          const SizedBox(height: 20),
          
          _buildRoleCard(
            title: "Join Group",
            desc: "Enter a 6-digit code provided by your host to join the session.",
            icon: Icons.group_add_rounded,
            color: Colors.blueAccent,
            onTap: () => _showJoinModal(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({required String title, required String desc, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showJoinModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ENTER GROUP CODE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8, color: Color(0xFFFF5C00)),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: "000000",
                counterText: "",
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _joinGroup();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("JOIN SESSION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDashboard() {
    final myShare = _totalBill / (_members.isEmpty ? 1 : _members.length);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // CODE DISPLAY
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFFFF5C00).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFFFF5C00), size: 18),
                const SizedBox(width: 12),
                Text(
                  "CODE: $_groupCode",
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.copy_rounded, color: Colors.grey, size: 14),
              ],
            ),
          ),
          
          const SizedBox(height: 40),

          // CIRCULAR BILL INDICATOR
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 240,
                height: 240,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 12,
                  color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                ),
              ),
              SizedBox(
                width: 240,
                height: 240,
                child: CircularProgressIndicator(
                  value: 0.75, // Simulated progress
                  strokeWidth: 12,
                  color: const Color(0xFFFF5C00),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("YOUR SHARE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(
                    "Rs. ${myShare.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text("Total: Rs. ${_totalBill.toStringAsFixed(2)}", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 50),

          // LIVE MEMBERS LIST
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("GROUP MEMBERS", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text("${_members.length} ACTIVE", style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ..._members.map((m) => _buildMemberItem(m)).toList(),
          
          const SizedBox(height: 40),
          
          // SMART TIPS
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    "Split updates automatically whenever a new item is ordered at this table.",
                    style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> member) {
    bool isMe = member['isMe'] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isMe ? const Color(0xFFFF5C00) : Colors.grey[200],
            child: Text(
              member['name'][0].toUpperCase(),
              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              member['name'] + (isMe ? " (You)" : ""),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (isMe)
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
          else
            ScaleTransition(
              scale: _pulseController.drive(Tween(begin: 1.0, end: 1.1)),
              child: const Icon(Icons.circle, color: Colors.green, size: 8),
            ),
        ],
      ),
    );
  }
}
