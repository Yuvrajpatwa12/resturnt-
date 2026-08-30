import 'package:flutter/material.dart';
import 'cart_manager.dart';

class MysteryBoxPage extends StatefulWidget {
  const MysteryBoxPage({super.key});

  @override
  State<MysteryBoxPage> createState() => _MysteryBoxPageState();
}

class _MysteryBoxPageState extends State<MysteryBoxPage> {
  @override
  Widget build(BuildContext context) {
    bool isWiFi = ShopManager.instance.isConnectedToRestaurantWiFi;
    bool isTime = ShopManager.instance.isMysteryBoxTime();
    bool isUnlocked = isWiFi && isTime;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Surprise Mystery Box",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.grey),
            onPressed: () => _showRules(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. STATUS HEADER ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatusPill(
                    isWiFi ? Icons.wifi : Icons.wifi_off,
                    isWiFi ? "ChiyaBreak WiFi: Connected" : "No WiFi Connection",
                    isWiFi ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  _buildStatusPill(
                    Icons.access_time,
                    isTime ? "Open (8am - 8pm)" : "Closed (Opens 8am)",
                    isTime ? const Color(0xFFFF5C00) : Colors.grey,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- 2. MAIN INTERACTIVE AREA ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ValueListenableBuilder<bool>(
                valueListenable: ShopManager.instance.isMysteryBoxOpened,
                builder: (context, isOpened, child) {
                  if (isOpened) {
                    return _buildOpenedStateUI();
                  }
                  return _buildLockedStateUI(isUnlocked);
                },
              ),
            ),

            const SizedBox(height: 60),

            // --- 3. RECENT WINS / HISTORY ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Previous Wins",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildPreviousWinsList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLockedStateUI(bool isUnlocked) {
    return Column(
      children: [
        GestureDetector(
          onTap: isUnlocked ? _handleOpenBox : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: isUnlocked ? Colors.amber.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
              border: Border.all(
                color: isUnlocked ? Colors.amber.withOpacity(0.5) : Colors.grey[200]!,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 120,
                  color: isUnlocked ? Colors.amber : Colors.grey[300],
                ),
                const SizedBox(height: 30),
                Text(
                  isUnlocked ? "Tap to Unbox!" : "Locked",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isUnlocked ? const Color(0xFFFF5C00) : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isUnlocked 
                    ? "Your surprise reward is waiting inside." 
                    : "Connect to ChiyaBreak's WiFi between 8am-8pm to unlock.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOpenedStateUI() {
    return ValueListenableBuilder<bool>(
      valueListenable: ShopManager.instance.isRewardClaimed,
      builder: (context, isClaimed, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: isClaimed ? Colors.grey[50] : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
            border: Border.all(color: isClaimed ? Colors.grey[200]! : const Color(0xFFFF5C00).withOpacity(0.2), width: 2),
          ),
          child: Column(
            children: [
              Icon(
                isClaimed ? Icons.check_circle : Icons.stars_rounded,
                color: isClaimed ? Colors.grey : const Color(0xFFFF5C00),
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                isClaimed ? "REWARD CLAIMED" : "FREE JAMOCHA SHAKE",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isClaimed ? Colors.grey : Colors.black87,
                  decoration: isClaimed ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isClaimed ? "Redeemed at 12:45 PM" : "Visit the counter to claim your item.",
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 30),
              if (!isClaimed)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showRewardSlip,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text("VIEW REWARD SLIP"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                )
              else
                const Text(
                  "Expires in 24 hours after claim",
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleOpenBox() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.pop(context);
          setState(() {
            ShopManager.instance.isMysteryBoxOpened.value = true;
          });
          _showWinCelebration();
        });
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard_rounded, size: 100, color: Colors.amber),
              const SizedBox(height: 20),
              const Text("Unboxing Your Gift...", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
            ],
          ),
        );
      },
    );
  }

  void _showWinCelebration() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("🎉 CONGRATS!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20)),
                child: Image.network('https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=300', height: 120),
              ),
              const SizedBox(height: 15),
              const Text("Free Jamocha Shake", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              const Text("Your reward is ready for pickup!", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("AWESOME!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRewardSlip() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("CHIYABREAK SURPRISE SLIP", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey, fontSize: 12)),
                const Divider(height: 30),
                const Text("FREE JAMOCHA SHAKE", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))),
                const SizedBox(height: 20),
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, size: 120),
                ),
                const SizedBox(height: 20),
                const Text("Valid today at ChiyaBreak Downtown Hub", style: TextStyle(fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        ShopManager.instance.isRewardClaimed.value = true;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reward Claimed & Slip Expired.")));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("CLAIM AT COUNTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("Mystery Box Rules", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text("1. Must be connected to ChiyaBreak's In-House WiFi.", textAlign: TextAlign.center),
            SizedBox(height: 10),
            Text("2. Available once daily between 8 AM and 8 PM.", textAlign: TextAlign.center),
            SizedBox(height: 10),
            Text("3. Reward slips must be claimed at the counter.", textAlign: TextAlign.center),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousWinsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildWinItem("Curly Fries", "Claimed 2 days ago"),
          _buildWinItem("Small Soda", "Claimed last week"),
        ],
      ),
    );
  }

  Widget _buildWinItem(String title, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: Colors.grey, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          const Text("Claimed", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }
}
