import 'package:flutter/material.dart';
import 'cart_manager.dart';

class PassportPage extends StatelessWidget {
  const PassportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ShopManager.instance.orderStampCount,
      builder: (context, collectedCount, child) {
        bool isGrandMaster = collectedCount >= 20;

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
              "Meat Master Passport",
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // --- 1. PROGRESS HEADER ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5C00).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "STAMPS: $collectedCount / 20",
                          style: const TextStyle(
                            color: Color(0xFFFF5C00),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Your Journey to Meat Mastery",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Earn one digital stamp for every order. Reach 20 stamps to unlock your Grand Master reward!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- 2. 20-STAMP GRID (4 COLUMNS) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 85,
                    ),
                    itemCount: 20,
                    itemBuilder: (context, index) {
                      bool isStamped = index < collectedCount;
                      return _buildSmallStamp(index + 1, isStamped);
                    },
                  ),
                ),

                const SizedBox(height: 40),

                // --- 3. GRAND MASTER REWARD ---
                _buildGrandMasterCard(context, isGrandMaster),
                
                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallStamp(int number, bool isStamped) {
    return Container(
      decoration: BoxDecoration(
        color: isStamped ? const Color(0xFFFF5C00).withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStamped ? const Color(0xFFFF5C00) : Colors.grey[200]!,
          width: 1.5,
        ),
      ),
      child: Center(
        child: isStamped 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFFFF5C00), size: 18),
                const SizedBox(height: 2),
                Text(
                  "$number", 
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00))
                ),
              ],
            )
          : Text(
              "$number", 
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[300])
            ),
      ),
    );
  }

  Widget _buildGrandMasterCard(BuildContext context, bool isUnlocked) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: isUnlocked ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isUnlocked ? const Color(0xFFD4AF37) : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: [
            if (isUnlocked)
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              )
          ],
        ),
        child: Column(
          children: [
            Icon(
              isUnlocked ? Icons.stars_rounded : Icons.lock_person_rounded,
              size: 50,
              color: isUnlocked ? const Color(0xFFD4AF37) : Colors.grey[400],
            ),
            const SizedBox(height: 15),
            Text(
              "GRAND MASTER OF MEATS",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isUnlocked ? const Color(0xFFD4AF37) : Colors.grey[500],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isUnlocked 
                ? "Congratulations! You've reached 20 orders. Your ultimate mystery reward is now available."
                : "Unlock this exclusive title and a massive mystery reward by reaching 20 stamps.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUnlocked ? () => _showMasterReward(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUnlocked ? const Color(0xFFFF5C00) : Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: Text(
                  isUnlocked ? "CLAIM MASTER REWARD" : "LOCKED (Reach 20)",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMasterReward(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("🏆 THE ULTIMATE PRIZE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 1.5, fontSize: 10)),
              const SizedBox(height: 12),
              const Text("MASTER OF MEATS", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))),
              const Divider(height: 40),
              const Text("FREE SIGNATURE PLATTER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.qr_code_2_rounded, size: 150),
              ),
              const SizedBox(height: 24),
              const Text("Show this to our staff to claim your mastery.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 30),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}
