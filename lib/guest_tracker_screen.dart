import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:chiyabreak/cart_manager.dart';

class GuestTrackerScreen extends StatefulWidget {
  const GuestTrackerScreen({super.key});

  @override
  State<GuestTrackerScreen> createState() => _GuestTrackerScreenState();
}

class _GuestTrackerScreenState extends State<GuestTrackerScreen> with SingleTickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color bgColor = Color(0xFFF8F9FA);

  late AnimationController _pulseController;
  bool _isTableLocked = false; 

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Simulate a lock event after 30 seconds for demo
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) setState(() => _isTableLocked = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ShopManager.instance;

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: session.liveSessionOrders,
      builder: (context, orders, _) {
        return ValueListenableBuilder<double>(
          valueListenable: session.liveSessionTotal,
          builder: (context, totalBill, _) {
            return ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: session.liveSessionMembers,
              builder: (context, members, _) {
                double myShare = members.isEmpty ? 0 : totalBill / members.length;

                return Scaffold(
                  backgroundColor: bgColor,
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    title: const Text(
                      "MY DINING SESSION", 
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)
                    ),
                    centerTitle: true,
                    actions: [
                      _buildLiveBadge(),
                      const SizedBox(width: 16),
                    ],
                  ),
                  body: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. GREETING & CONTEXT
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ValueListenableBuilder<String>(
                                      valueListenable: session.customerName,
                                      builder: (context, name, _) => Text(
                                        "Namaste, ${name.isNotEmpty ? name : 'Guest'}!", 
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)
                                      ),
                                    ),
                                    const Text(
                                      "Table #04 • Live Sync Active 👑", 
                                      style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                                  ),
                                  child: const Icon(Icons.sync_rounded, color: Colors.green, size: 20),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 32),

                            // 2. HERO "MY SHARE" GLASSMORPHIC CARD
                            _buildHeroShareCard(myShare, totalBill, members.length),

                            const SizedBox(height: 32),

                            // 3. LIVE MEMBER PULSE
                            _buildSectionHeader("ACTIVE DINERS"),
                            const SizedBox(height: 16),
                            _buildMemberPulseRow(members),

                            const SizedBox(height: 32),

                            // 4. TABLE-WIDE ACTIVITY (Transparency)
                            _buildSectionHeader("TABLE-WIDE ACTIVITY"),
                            const SizedBox(height: 16),
                            
                            if (orders.isEmpty)
                              _buildEmptyActivityState()
                            else
                              ...orders.map((a) => _buildActivityItem(
                                a['title'] as String, 
                                a['who'] ?? "Guest", 
                                a['status'] as String, 
                                a['price'] is double ? "Rs. ${a['price']}" : a['price'].toString(),
                              )).toList(),

                            const SizedBox(height: 40),
                            
                            // 5. ACTION AREA
                            _buildActionButtons(),
                            
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                      
                      // 6. PREMIUM LOCK OVERLAY
                      if (_isTableLocked)
                        _buildLockOverlay(),
                    ],
                  ),
                );
              }
            );
          }
        );
      }
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseController.drive(Tween(begin: 1.0, end: 1.3)),
            child: const CircleAvatar(radius: 3, backgroundColor: Colors.green),
          ),
          const SizedBox(width: 8),
          const Text(
            "LIVE SYNC", 
            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
          ),
        ],
      ),
    );
  }

  Widget _buildHeroShareCard(double share, double total, int dinerCount) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: primaryBlue.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 15))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "YOUR INDIVIDUAL SHARE", 
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                      child: const Text("Equal Split", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text("Rs. ", style: TextStyle(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: share),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: -1),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text("NPR", style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeroStat("Table Total", "Rs. ${total.toInt()}"),
                    _buildHeroStat("Active Diners", "$dinerCount People"),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title, 
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.5)
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: Colors.grey.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildMemberPulseRow(List<Map<String, dynamic>> members) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        itemBuilder: (context, index) {
          final m = members[index];
          final String name = m['name'] ?? 'Diner';
          final String gender = m['gender'] ?? 'Male';
          final Color color = gender == 'Female' ? Colors.pink : Colors.blue;

          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: _pulseController.drive(Tween(begin: 1.0, end: 1.2)),
                      child: Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withOpacity(0.5), width: 2),
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: color.withOpacity(0.1),
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(String title, String who, String status, String price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accentOrange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.restaurant_rounded, color: accentOrange, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text("Ordered by $who", style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: primaryBlue)),
              Text(status.toUpperCase(), style: TextStyle(color: status == 'Served' ? Colors.green : Colors.orange, fontSize: 9, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty_rounded, color: Colors.grey[300], size: 40),
          const SizedBox(height: 12),
          const Text("Waiting for first order...", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLockOverlay() {
    return Positioned.fill(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.white.withOpacity(0.4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.lock_person_rounded, color: primaryBlue, size: 32),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "ORDERING LOCKED", 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "The host is finalizing the bill. Please proceed to payment summary.", 
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("VIEW FINAL BILL", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: accentOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: const Text("ORDER MORE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 56, width: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primaryBlue.withOpacity(0.1)),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_active_outlined, color: primaryBlue),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}
