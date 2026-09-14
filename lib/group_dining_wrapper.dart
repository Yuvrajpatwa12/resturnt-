import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chiyabreak/host_hub_screen.dart';
import 'package:chiyabreak/guest_tracker_screen.dart';
import 'package:chiyabreak/smart_split_screen.dart';
import 'package:chiyabreak/group_chat_page.dart';
import 'package:chiyabreak/services/tenant_service.dart';
import 'package:chiyabreak/cart_manager.dart';
import 'package:chiyabreak/services/api_service.dart';

class GroupDiningWrapper extends StatefulWidget {
  const GroupDiningWrapper({super.key});

  @override
  State<GroupDiningWrapper> createState() => _GroupDiningWrapperState();
}

class _GroupDiningWrapperState extends State<GroupDiningWrapper> {
  bool? _isHost;
  int _currentIndex = 0;
  bool _termsAccepted = false;
  bool _isLoading = false;
  String? _tablePin;
  final TextEditingController _pinController = TextEditingController();

  void _selectRole(bool host) async {
    if (!_termsAccepted) return;
    
    final tenant = TenantService().currentTenant.value;
    final tableId = ShopManager.instance.selectedTableId.value;

    if (tenant == null || tableId == null) {
      // Redirect to Home and open Table Picker
      ShopManager.instance.currentTabIndex.value = 0;
      ShopManager.instance.openTablePickerTrigger.value = true;
      Navigator.pop(context);
      return;
    }

    if (host) {
      setState(() => _isLoading = true);
      final res = await ApiService.createSplitGroup(
        tenantId: tenant.id, 
        userId: ShopManager.instance.currentUserId, 
        tableNumber: tableId
      );

      if (res != null) {
        final String generatedPin = res['pin'].toString();
        ShopManager.instance.startSessionPolling(res['session_id'], true, pin: generatedPin);
        setState(() {
          _isHost = true;
          _tablePin = generatedPin;
          _isLoading = false;
          _currentIndex = 0;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error creating session. Try again.")));
      }
    }
  }

  void _onPinSubmit() async {
    final pin = _pinController.text.trim();
    if (pin.length != 5) return;

    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isLoading = true);
    final res = await ApiService.joinSplitGroup(
      tenantId: tenant.id, 
      userId: ShopManager.instance.currentUserId, 
      pin: pin
    );

    if (res != null) {
      ShopManager.instance.startSessionPolling(res['session_id'], false, pin: pin);
      setState(() {
        _isHost = false;
        _tablePin = pin;
        _isLoading = false;
        _currentIndex = 0;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid PIN or Session Expired.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: ShopManager.instance.activeSessionId,
      builder: (context, sid, _) {
        if (sid == null) {
          return _buildRoleSelection();
        }

        final bool isHost = ShopManager.instance.isSessionHost.value;
        
        return ValueListenableBuilder<String?>(
          valueListenable: ShopManager.instance.activeSessionPin,
          builder: (context, pin, _) {
            final displayPin = pin ?? "";

            final List<Widget> tabs = isHost 
                ? [HostHubScreen(tablePin: displayPin), const GroupChatPage(), const SmartSplitScreen(isIntegrated: true)]
                : [const GuestTrackerScreen(), const GroupChatPage()];

            final List<Map<String, dynamic>> navItems = isHost
                ? [
                    {'icon': Icons.storefront_outlined, 'label': "Host Hub"},
                    {'icon': Icons.chat_bubble_outline_rounded, 'label': "Group Chat"},
                    {'icon': Icons.analytics_outlined, 'label': "Smart Split"},
                  ]
                : [
                    {'icon': Icons.people_outline, 'label': "Tracker"},
                    {'icon': Icons.chat_bubble_outline_rounded, 'label': "Group Chat"},
                  ];

            return Scaffold(
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex >= navItems.length ? 0 : _currentIndex,
                children: tabs,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: ShopManager.instance.showPaymentPopup,
                builder: (context, show, _) {
                  if (!show) return const SizedBox.shrink();
                  return Positioned(
                    top: 100,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("PAYMENT REQUEST!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                Text("The host has requested payment. Check Group Chat!", style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ShopManager.instance.showPaymentPopup.value = false;
                              setState(() => _currentIndex = 1); 
                            },
                            child: const Text("VIEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: BottomAppBar(
                color: Colors.white,
                elevation: 30,
                padding: EdgeInsets.zero,
                height: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(navItems.length, (index) {
                    return _buildNavItem(index, navItems[index]['icon'], navItems[index]['label']);
                  }),
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildRoleSelection() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
        : Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF4F6F9)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Text(
                  "Chiyala Dining\nExperience",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TERMS & CONDITIONS",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "• Only one host can manage the table bill.\n• Joined members can view orders in real-time.\n• Final bill split requires host approval.\n• Ensure you are at the correct table before joining.",
                        style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Checkbox(
                            value: _termsAccepted,
                            activeColor: const Color(0xFFF97316),
                            onChanged: (val) => setState(() => _termsAccepted = val!),
                          ),
                          const Expanded(
                            child: Text(
                              "I agree to the Dining Terms & Session Sync Rules",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Choose your session role",
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _buildUniqueRoleButton(
                  title: "Host New Session",
                  subtitle: "Get a 5-digit PIN for your group",
                  icon: Icons.add_moderator_rounded,
                  color: const Color(0xFFF97316),
                  isActive: _termsAccepted,
                  onTap: () => _selectRole(true),
                ),
                const SizedBox(height: 20),
                _buildUniqueRoleButton(
                  title: "Join Existing Group",
                  subtitle: "Enter PIN to track table orders",
                  icon: Icons.group_add_rounded,
                  color: const Color(0xFF1E3A8A),
                  isActive: _termsAccepted && !ShopManager.instance.isSessionHost.value,
                  onTap: () => _showPinEntryDialog(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUniqueRoleButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isActive ? 1.0 : 0.4,
      child: InkWell(
        onTap: isActive ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isActive ? color.withOpacity(0.2) : Colors.transparent, width: 2),
            boxShadow: [
              if (isActive)
                BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
            ],
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
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isActive ? color : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showPinEntryDialog() {
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text("ENTER TABLE PIN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1)),
            const SizedBox(height: 8),
            const Text("Ask the host for the 5-digit numeric code", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 32),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 5,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 20, color: Color(0xFF1E3A8A)),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: "00000",
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
                  _onPinSubmit();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("JOIN SESSION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? const Color(0xFF1E3A8A) : Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? const Color(0xFF1E3A8A) : Colors.grey, fontSize: 10, fontWeight: isActive ? FontWeight.w900 : FontWeight.w500)),
          if (isActive)
            Container(margin: const EdgeInsets.only(top: 4), height: 3, width: 20, decoration: BoxDecoration(color: const Color(0xFF1E3A8A), borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }
}
