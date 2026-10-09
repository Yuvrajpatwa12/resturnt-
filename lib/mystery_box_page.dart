import 'dart:async';
import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'services/api_service.dart';
import 'services/tenant_service.dart';
import 'widgets/smart_auth_overlay.dart';

class MysteryBoxPage extends StatefulWidget {
  const MysteryBoxPage({super.key});

  @override
  State<MysteryBoxPage> createState() => _MysteryBoxPageState();
}

class _MysteryBoxPageState extends State<MysteryBoxPage> {
  bool _isProcessing = false;
  bool _isLoadingClaims = true;
  List<Map<String, dynamic>> _liveClaims = [];
  Map<String, dynamic>? _wonPrize;
  String? _claimCode;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadRealClaims();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _liveClaims.isNotEmpty) {
        setState(() {});
      }
    });
  }

  Future<void> _loadRealClaims() async {
    await ShopManager.instance.ensureInitialized();

    final tenant = TenantService().currentTenant.value;
    final staff = TenantService().currentStaff.value;
    final String currentUid = ShopManager.instance.currentUserId;
    final String guestId = ShopManager.instance.guestId.value;
    final String email = ShopManager.instance.customerEmail.value;

    final String uid = staff != null ? staff.id.toString() : currentUid;

    if (tenant == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _liveClaims = [];
          _isLoadingClaims = false;
        });
      }
      return;
    }

    setState(() => _isLoadingClaims = true);
    final history = await ApiService.fetchClaimHistory(tenant.id, uid, guestId);
    if (mounted) {
      setState(() {
        final String searchUid = uid.trim().toLowerCase();
        final String searchGuest = guestId.trim().toLowerCase();
        final String searchEmail = email.trim().toLowerCase();

        List<Map<String, dynamic>> fetched = (history ?? []).where((c) {
          final cUid = (c['user_id'] ?? '').toString().trim().toLowerCase();
          if (cUid.isEmpty || cUid == 'guest') return false;
          return cUid == searchUid || cUid == searchGuest || (searchEmail.isNotEmpty && cUid == searchEmail);
        }).toList();

        // Ensure newly won prize is preserved if not present in server response yet
        if (_wonPrize != null) {
          final String wCode = (_wonPrize!['claim_code'] ?? '').toString();
          if (wCode.isNotEmpty && !fetched.any((c) => (c['claim_code'] ?? '').toString() == wCode)) {
            fetched.insert(0, _wonPrize!);
          }
        }

        _liveClaims = fetched;

        // Auto-restore today's unboxed prize if user already claimed today
        final DateTime now = DateTime.now();
        Map<String, dynamic>? todayClaim;

        for (var claim in fetched) {
          final dateStr = (claim['created_at'] ?? '').toString();
          if (dateStr.isNotEmpty) {
            try {
              final dt = DateTime.parse(dateStr);
              if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                todayClaim = claim;
                break;
              }
            } catch (_) {}
          }
        }

        // Fallback: If no date match but user has a pending claim from today or recent
        if (todayClaim == null && fetched.isNotEmpty) {
          final first = fetched.first;
          final String st = (first['status'] ?? '').toString().toLowerCase();
          if (st == 'pending') {
            todayClaim = first;
          }
        }

        if (todayClaim != null) {
          _wonPrize = todayClaim;
          _claimCode = todayClaim['claim_code'];
          ShopManager.instance.isMysteryBoxOpened.value = true;
          final String st = (todayClaim['status'] ?? 'pending').toString().toLowerCase();
          final String redAt = (todayClaim['redeemed_at'] ?? '').toString().trim();
          ShopManager.instance.isRewardClaimed.value =
              (st == 'redeemed' || st == 'claimed' || st == 'claimed_by_staff' || st == 'verified' || (redAt.isNotEmpty && redAt != 'null'));
        } else {
          if (_wonPrize == null) {
            ShopManager.instance.isMysteryBoxOpened.value = false;
            ShopManager.instance.isRewardClaimed.value = false;
          }
        }

        _isLoadingClaims = false;
      });
    }
  }

  DateTime _parseServerDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();
    try {
      String formatted = dateStr.replaceAll(' ', 'T');
      DateTime parsed = DateTime.parse(formatted);
      if (!formatted.contains('Z') && !formatted.contains('+')) {
        final utcParsed = DateTime.utc(
          parsed.year, parsed.month, parsed.day,
          parsed.hour, parsed.minute, parsed.second,
        );
        final diffLocal = DateTime.now().difference(parsed).abs();
        final diffUtc = DateTime.now().difference(utcParsed.toLocal()).abs();
        if (diffUtc < diffLocal) {
          return utcParsed.toLocal();
        }
      }
      return parsed;
    } catch (_) {
      return DateTime.now();
    }
  }

  // Calculate 6-hour expiration remaining duration
  Duration _getRemainingExpiryTime(Map<String, dynamic> win) {
    final dateStr = (win['created_at'] ?? '').toString();
    if (dateStr.isEmpty) return const Duration(hours: 6);
    try {
      final createdAt = _parseServerDate(dateStr);
      final expiryTime = createdAt.add(const Duration(hours: 6));
      final remaining = expiryTime.difference(DateTime.now());
      if (remaining.isNegative) return Duration.zero;
      return remaining;
    } catch (_) {
      return const Duration(hours: 6);
    }
  }

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return "00h 00m 00s";
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "${hours}h ${minutes}m ${seconds}s";
  }

  @override
  Widget build(BuildContext context) {
    bool isWiFi = ShopManager.instance.isConnectedToRestaurantWiFi.value;
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

            const SizedBox(height: 50),

            // --- 3. RECENT WINS / HISTORY ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Previous Wins & Claims",
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
    final bool isSynced = ShopManager.instance.isEmailSynced.value;
    final bool canUnbox = isUnlocked && isSynced;

    return Column(
      children: [
        if (!isSynced) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF5C00).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Color(0xFFFF5C00), size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Gmail Sync Required", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      Text("Sync your Google Email to unlock today's Mystery Box.", style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => SmartAuthOverlay.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("SYNC NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],

        GestureDetector(
          onTap: () {
            if (!isSynced) {
              SmartAuthOverlay.show(context);
            } else if (isUnlocked) {
              _handleOpenBox();
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: canUnbox ? Colors.amber.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
              border: Border.all(
                color: canUnbox ? Colors.amber.withValues(alpha: 0.5) : Colors.grey[200]!,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 120,
                  color: canUnbox ? Colors.amber : Colors.grey[300],
                ),
                const SizedBox(height: 30),
                Text(
                  canUnbox ? "Tap to Unbox!" : (!isSynced ? "Sync Gmail to Unlock" : "Locked"),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: canUnbox ? const Color(0xFFFF5C00) : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  !isSynced 
                    ? "Tap here or 'SYNC NOW' to connect your Gmail."
                    : (isUnlocked 
                        ? "Your surprise reward is waiting inside." 
                        : "Connect to ChiyaBreak's WiFi between 8am-8pm to unlock."),
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

  // Completed State UI shown at the top after unboxing today
  Widget _buildOpenedStateUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: const Color(0xFFFF5C00),
              size: 60,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Daily Limit Reached!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "You have already opened today's Mystery Box.\nTap your reward below in 'Previous Wins' to view code & QR!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Text(
              "Opens again tomorrow at 8:00 AM",
              style: TextStyle(
                color: Color(0xFFFF5C00),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOpenBox() async {
    if (!ShopManager.instance.isEmailSynced.value) {
      SmartAuthOverlay.show(context);
      return;
    }
    await ShopManager.instance.ensureInitialized();
    final tenant = TenantService().currentTenant.value;
    final staff = TenantService().currentStaff.value;
    final uid = staff != null ? staff.id.toString() : ShopManager.instance.currentUserId;
    if (tenant == null || uid.isEmpty) return;

    setState(() => _isProcessing = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard_rounded, size: 100, color: Colors.amber),
            const SizedBox(height: 20),
            const Text("Unboxing Your Gift...", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );

    final String userName = ShopManager.instance.customerName.value;
    final res = await ApiService.openMysteryBox(tenant.id, uid, userName);
    
    if (!mounted) return;
    Navigator.pop(context); // Close unboxing dialog

    if (res != null && res['status'] == 'success') {
      final Map<String, dynamic> rawWin = Map<String, dynamic>.from(res['data'] ?? {});
      rawWin['status'] = 'pending';
      rawWin['claim_code'] = res['claim_code'];
      rawWin['user_id'] = uid;
      rawWin['created_at'] = DateTime.now().toIso8601String();

      setState(() {
        _wonPrize = rawWin;
        _claimCode = res['claim_code'];
        ShopManager.instance.isMysteryBoxOpened.value = true;

        bool exists = _liveClaims.any((c) => c['claim_code'] == res['claim_code']);
        if (!exists) {
          _liveClaims.insert(0, rawWin);
        }
      });
      _loadRealClaims();
      _showWinCelebration();
    } else if (res != null && res['status'] == 'limit_reached') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.access_time_filled_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text("Daily Limit Reached", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            ],
          ),
          content: Text(
            res['message'] ?? "You have already claimed today's Mystery Box! Come back tomorrow for a new surprise.",
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("GOT IT"),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? "Failed to open box.")));
    }
    
    setState(() => _isProcessing = false);
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
                child: Image.network(
                  _wonPrize?['image_url'] ?? 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=300', 
                  height: 120,
                  errorBuilder: (_,__,___) => const Icon(Icons.stars_rounded, size: 80, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 15),
              Text(_wonPrize?['reward_name'] ?? "Surprise Item", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              const Text("Your reward is added to Previous Wins below!", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                  child: const Text("SEE MY REWARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRewardSlipModal(Map<String, dynamic> win) {
    showDialog(
      context: context,
      builder: (context) {
        Timer? dialogTimer;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (context.mounted) {
                setDialogState(() {});
              } else {
                timer.cancel();
              }
            });

            final String title = win['reward_name'] ?? win['reward_title'] ?? win['title'] ?? 'Mystery Prize';
            final String code = win['claim_code'] ?? '';
            final String status = (win['status'] ?? 'pending').toString().toLowerCase();
            final String redAt = (win['redeemed_at'] ?? '').toString().trim();
            final bool isRedeemed = status == 'redeemed' || status == 'claimed' || status == 'claimed_by_staff' || status == 'verified' || (redAt.isNotEmpty && redAt != 'null');
            final remaining = _getRemainingExpiryTime(win);
            final bool isExpired = !isRedeemed && remaining <= Duration.zero;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("CHIYABREAK SURPRISE SLIP", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey, fontSize: 12)),
                    const Divider(height: 30),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text("CODE: $code", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 20),
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isExpired
                            ? Icons.timer_off_rounded
                            : (isRedeemed ? Icons.check_circle_outline_rounded : Icons.qr_code_2_rounded),
                        size: 110,
                        color: isExpired ? Colors.red : (isRedeemed ? Colors.green : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isRedeemed)
                      const Text("✅ Verified & Redeemed by Waiter", style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold))
                    else if (isExpired)
                      const Text("❌ Reward Expired (6 Hours Time Limit Exceeded)", style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold))
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time_filled_rounded, size: 16, color: Color(0xFFFF5C00)),
                          const SizedBox(width: 6),
                          Text(
                            "Expires in: ${_formatDuration(remaining)}",
                            style: const TextStyle(fontSize: 14, color: Color(0xFFFF5C00), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          dialogTimer?.cancel();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("CLOSE SLIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
            Text("3. Rewards expire 6 hours after unboxing if not claimed.", textAlign: TextAlign.center),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousWinsList() {
    if (_isLoadingClaims) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_liveClaims.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: const Center(
            child: Text(
              "No previous wins yet. Open mystery boxes to win rewards!",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _liveClaims.map((w) => _buildWinItem(w)).toList(),
      ),
    );
  }

  Widget _buildWinItem(Map<String, dynamic> win) {
    final String title = win['reward_name'] ?? win['reward_title'] ?? win['title'] ?? 'Mystery Prize';
    final String status = (win['status'] ?? 'pending').toString().toLowerCase();
    final String redAt = (win['redeemed_at'] ?? '').toString().trim();
    final bool isRedeemed = status == 'redeemed' || status == 'claimed' || status == 'claimed_by_staff' || status == 'verified' || (redAt.isNotEmpty && redAt != 'null');
    final String code = win['claim_code'] ?? '';
    final remaining = _getRemainingExpiryTime(win);
    final bool isExpired = !isRedeemed && remaining <= Duration.zero;

    Color badgeBg;
    Color badgeText;
    String badgeTitle;

    if (isRedeemed) {
      badgeBg = Colors.green.shade50;
      badgeText = Colors.green.shade800;
      badgeTitle = "Redeemed";
    } else if (isExpired) {
      badgeBg = Colors.red.shade50;
      badgeText = Colors.red.shade800;
      badgeTitle = "Expired";
    } else {
      badgeBg = Colors.orange.shade50;
      badgeText = Colors.orange.shade900;
      badgeTitle = "Pending";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpired ? Colors.red.shade100 : Colors.grey[100]!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showRewardSlipModal(win),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isRedeemed
                      ? Icons.check_circle_rounded
                      : (isExpired ? Icons.highlight_off_rounded : Icons.pending_actions_rounded),
                  color: isRedeemed ? Colors.green : (isExpired ? Colors.red : Colors.orange),
                  size: 24,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(
                        isRedeemed
                            ? "Verified & Redeemed by Waiter"
                            : (isExpired
                                ? "Expired (6h Claim Limit Exceeded)"
                                : (code.isNotEmpty
                                    ? "Code: $code • Expires in ${_formatDuration(remaining)}"
                                    : "Expires in ${_formatDuration(remaining)}")),
                        style: TextStyle(
                          color: isRedeemed
                              ? Colors.grey[600]
                              : (isExpired ? Colors.red.shade700 : Colors.orange.shade900),
                          fontSize: 11,
                          fontWeight: isRedeemed ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeTitle,
                    style: TextStyle(
                      color: badgeText,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
