import 'dart:ui';
import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'services/api_service.dart';

class SmartSplitScreen extends StatefulWidget {
  final bool isIntegrated;
  const SmartSplitScreen({super.key, this.isIntegrated = false});

  @override
  State<SmartSplitScreen> createState() => _SmartSplitScreenState();
}

class _SmartSplitScreenState extends State<SmartSplitScreen> {
  // Theme Colors from Blueprint
  static const Color bgColor = Color(0xFFF4F6F9);
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color cardWhite = Colors.white;

  String? selectedVolunteerId; 
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final session = ShopManager.instance;

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: session.liveSessionMembers,
      builder: (context, members, _) {
        return ValueListenableBuilder<double>(
          valueListenable: session.liveSessionTotal,
          builder: (context, totalBill, _) {
            // Logic
            final int memberCount = members.length;
            final int flatPay = memberCount == 0 ? 0 : (totalBill / memberCount).floor();
            final double remainder = totalBill - (flatPay * memberCount);

            // Default selection if none
            if (selectedVolunteerId == null && members.isNotEmpty) {
               selectedVolunteerId = members[0]['user_id'];
            }

            return Scaffold(
              backgroundColor: bgColor,
              appBar: widget.isIntegrated ? null : _buildAppBar(),
              body: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // 1. Top Summary Card
                        _buildTopSummaryCard(totalBill, memberCount),
                        
                        const SizedBox(height: 16),
                        // 2. Smart Paisa Friction Solver Banner
                        _buildFrictionSolverBanner(totalBill, memberCount, remainder),

                        const SizedBox(height: 24),
                        // 3. Absorbing the Remainder List
                        _buildVolunteerList(members, flatPay, remainder),

                        const SizedBox(height: 120), // Bottom padding for FAB
                      ],
                    ),
                  ),
                  if (_isSharing)
                    _buildSharingOverlay(),
                ],
              ),
              floatingActionButton: _buildShareButton(flatPay, remainder),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            );
          }
        );
      }
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: accentOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.restaurant_menu, color: accentOrange, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Chiyala •", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
              Text("SMART SPLIT", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text("#CHIYA-SESSION", style: TextStyle(color: primaryBlue.withValues(alpha: 0.6), fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildTopSummaryCard(double total, int diners) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("TOTAL BILL TO SETTLE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Text("● Split Active", style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text("NPR ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(total.toInt().toString(), 
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text("Includes All Charges • $diners Diners", 
              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildFrictionSolverBanner(double total, int count, double rem) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentOrange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentOrange.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: accentOrange, size: 14),
                  SizedBox(width: 8),
                  Text("Smart Paisa Friction Solver", style: TextStyle(color: accentOrange, fontWeight: FontWeight.w900, fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text("Odd: Rs. ${rem.toInt()}", style: const TextStyle(color: accentOrange, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Mathematical split is Rs. ${count == 0 ? 0 : (total/count).toStringAsFixed(2)}. 1 volunteer absorbs the small Rs. ${rem.toInt()} remainder so everyone else transfers a clean flat note.",
            style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerList(List<Map<String, dynamic>> members, int flat, double rem) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_outline, color: primaryBlue, size: 18),
                  SizedBox(width: 8),
                  Text("Who's Absorbing the\nRemainder?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87, height: 1.1)),
                ],
              ),
              Text("Tap to\nswap", textAlign: TextAlign.right, style: TextStyle(color: primaryBlue.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ...members.map((diner) {
            final bool isVolunteer = selectedVolunteerId == diner['user_id'];
            final int payAmount = isVolunteer ? (flat + rem.toInt()) : flat;

            return GestureDetector(
              onTap: () => setState(() => selectedVolunteerId = diner['user_id']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isVolunteer ? primaryBlue : Colors.transparent, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20, 
                      backgroundColor: (diner['gender'] == 'Female' ? Colors.pink : Colors.blue).withValues(alpha: 0.1),
                      child: Text(diner['name'][0], style: TextStyle(color: diner['gender'] == 'Female' ? Colors.pink : Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(diner['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (isVolunteer) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text("+Rs. ${rem.toInt()} Extra", style: const TextStyle(color: primaryBlue, fontSize: 8, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ],
                          ),
                          Text(isVolunteer ? "Volunteered to absorb 50p rounding" : "Flat share", 
                            style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Rs. $payAmount", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: primaryBlue)),
                        Text(isVolunteer ? "Clean Pay" : "Flat Pay", style: TextStyle(color: primaryBlue.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      isVolunteer ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isVolunteer ? primaryBlue : Colors.grey.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildShareButton(int flat, double rem) {
    if (!ShopManager.instance.isSessionHost.value) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ElevatedButton.icon(
        onPressed: _shareToGroupChat,
        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        label: const Text("SHARE SPLIT TO GROUP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentOrange,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 10,
          shadowColor: accentOrange.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Future<void> _shareToGroupChat() async {
    final sid = ShopManager.instance.activeSessionId.value;
    if (sid == null || selectedVolunteerId == null) return;

    setState(() => _isSharing = true);
    
    final success = await ApiService.shareSplitDetails(sid, selectedVolunteerId!);

    if (success) {
      await Future.delayed(const Duration(seconds: 1)); // For animation feel
      ShopManager.instance.syncSessionData();
      if (mounted) {
        setState(() => _isSharing = false);
        // Switch to Group Chat Tab
        ShopManager.instance.currentTabIndex.value = 1; 
      }
    } else {
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to share split. Try again.")));
      }
    }
  }

  Widget _buildSharingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: accentOrange),
                const SizedBox(height: 24),
                const Text(
                  "GENERATING SMART SPLIT...",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Notifying all diners in Group Chat",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
