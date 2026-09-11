import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class ClaimDetailsModal extends StatelessWidget {
  final Map<String, dynamic> claim;

  const ClaimDetailsModal({super.key, required this.claim});

  @override
  Widget build(BuildContext context) {
    final String code = claim['claim_code'] ?? 'ERR-000';
    final String title = claim['reward_title'] ?? 'Mystery Prize';
    final String dateStr = claim['created_at'] ?? DateTime.now().toString();
    final bool isClaimed = claim['status'] == 'Claimed';
    
    DateTime date;
    try { date = DateTime.parse(dateStr); } catch (e) { date = DateTime.now(); }

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
    
            // Reward Title
            Text(
              title, 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              "Claimed on ${DateFormat('MMM dd, yyyy').format(date)}", 
              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
            ),
    
            const SizedBox(height: 32),
    
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isClaimed ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFFFF5C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: isClaimed ? Colors.blue : const Color(0xFFFF5C00), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isClaimed ? Icons.check_circle_outline : Icons.pending_actions_rounded, 
                       color: isClaimed ? Colors.blue : const Color(0xFFFF5C00), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isClaimed ? "SERVED" : "ACTIVE", 
                    style: TextStyle(
                      color: isClaimed ? Colors.blue : const Color(0xFFFF5C00), 
                      fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1
                    )
                  ),
                ],
              ),
            ),
    
            const SizedBox(height: 32),
    
            // QR CODE SECTION
            if (!isClaimed)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                    ),
                    child: QrImageView(
                      data: code,
                    version: QrVersions.auto,
                    size: 180.0,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E293B)),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E293B)),
                  ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "SHOW THIS TO WAITER", 
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.grey)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    code, 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4, color: Color(0xFF1E293B))
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
                    SizedBox(height: 16),
                    Text(
                      "REWARD SERVED", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)
                    ),
                    SizedBox(height: 8),
                    Text(
                      "You have already enjoyed this reward.", 
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
    
            const SizedBox(height: 40),
    
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
