import 'dart:ui';
import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'services/api_service.dart';
import 'services/tenant_service.dart';

class GroupChatPage extends StatefulWidget {
  final bool showBackButton;
  const GroupChatPage({super.key, this.showBackButton = false});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _controller = TextEditingController();
  
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accentOrange = Color(0xFFF97316);

  Future<void> _requestPayment() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final sid = ShopManager.instance.activeSessionId.value;
    if (sid == null) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading Payment QR...")));
    final url = await ApiService.uploadGroupQR(sid, bytes, image.name);

    if (url != null) {
      ShopManager.instance.activeSessionQr.value = url;
      ShopManager.instance.isSessionLocked.value = true;
      ShopManager.instance.syncSessionData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Request Sent!")));
    }
  }

  Future<void> _uploadPaymentSS() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final sid = ShopManager.instance.activeSessionId.value;
    final uid = ShopManager.instance.currentUserId;
    if (sid == null || uid.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading Payment Proof...")));
    final url = await ApiService.submitGroupPayment(sid, uid, bytes, image.name);

    if (url != null) {
      ShopManager.instance.syncSessionData();
      _showPaymentConfirmationPopup();
    }
  }

  void _showPaymentConfirmationPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Payment Done?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("Has your transaction been successfully completed? This will notify the host."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NO", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Host has been notified!"), backgroundColor: Colors.green));
            },
            child: const Text("YES, PAID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ShopManager.instance;

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: session.liveSessionMembers,
      builder: (context, members, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            automaticallyImplyLeading: false,
            leading: widget.showBackButton ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ) : null,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("GROUP SETTLEMENT", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text(
                  "Table #04 • ${members.length} Diners Active", 
                  style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            actions: [
              if (session.isSessionHost.value && !session.isSessionLocked.value)
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: accentOrange, size: 24),
                  tooltip: "Request Payment",
                  onPressed: _requestPayment,
                ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: ValueListenableBuilder<bool>(
            valueListenable: session.isSplitShared,
            builder: (context, isShared, _) {
              if (!isShared || session.isSessionHost.value) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                onPressed: _uploadPaymentSS,
                backgroundColor: primaryBlue,
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                label: const Text("UPLOAD PROOF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              );
            },
          ),
          body: ValueListenableBuilder<bool>(
            valueListenable: session.isSplitShared,
            builder: (context, isShared, _) {
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (!isShared)
                          _buildWaitingState()
                        else ...[
                          ValueListenableBuilder<String?>(
                            valueListenable: session.activeSessionQr,
                            builder: (context, qrUrl, _) {
                              return _buildPaymentRequestCard(qrUrl);
                            },
                          ),
                          const SizedBox(height: 32),
                          _buildMemberStatusList(members),
                        ],
                      ],
                    ),
                  ),
                  if (!isShared) _buildInputBar(),
                ],
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(25)),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Message everyone...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.send, color: primaryBlue),
            onPressed: () {
               // Texting logic disabled per settlement requirements
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        Icon(Icons.hourglass_empty_rounded, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 24),
        const Text(
          "WAITING FOR HOST...",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.grey, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        const Text(
          "The bill is being calculated using Smart Split.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMemberStatusList(List<Map<String, dynamic>> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("MEMBER PAYMENT STATUS", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 16),
        ...members.map((m) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: (m['gender'] == 'Female' ? Colors.pink : Colors.blue).withValues(alpha: 0.1),
                child: Text(m['name'] != null && m['name'].isNotEmpty ? m['name'][0] : "?", style: TextStyle(color: m['gender'] == 'Female' ? Colors.pink : Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(m['name'] ?? "Guest", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (m['is_paid'] == 1 || m['is_paid'] == true)
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
              else
                const Text("Pending", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 10)),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildPaymentRequestCard(String? qrUrl) {
    final session = ShopManager.instance;
    final bool isHost = session.isSessionHost.value;
    final double totalBill = session.liveSessionTotal.value;
    final int memberCount = session.liveSessionMembers.value.length;
    final String? vId = session.volunteerId.value;
    final String myId = session.currentUserId;

    // Calculate individual share
    final int flatPay = memberCount == 0 ? 0 : (totalBill / memberCount).floor();
    final double remainder = totalBill - (flatPay * memberCount);
    final int myShare = (myId == vId) ? (flatPay + remainder.toInt()) : flatPay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryBlue, Color(0xFF2563EB)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHost ? "PAYMENT TRACKER ACTIVE" : "YOUR SHARE DETAILS",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                    ),
                    Text(
                      isHost ? "Group Total: Rs. ${totalBill.toInt()}" : "Amount: Rs. $myShare",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                if (qrUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(qrUrl, height: 140, width: 140, fit: BoxFit.cover),
                  )
                else
                  Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: primaryBlue),
                        const SizedBox(height: 16),
                        Text(
                          isHost ? "UPLOADING QR..." : "WAITING FOR HOST...",
                          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const Text("SCAN TO PAY", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: primaryBlue, letterSpacing: 2)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isHost ? "Review and verify payments from members" : "Pay via eSewa/Khalti and upload proof below",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
