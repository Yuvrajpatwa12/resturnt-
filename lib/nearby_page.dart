import 'package:flutter/material.dart';
import 'dart:async';
import 'cart_manager.dart';
import 'messages_list_page.dart';
import 'user_profile_view_page.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  List<Map<String, dynamic>> _activeGuests = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  final Set<String> _loadingFollowIds = {}; 
  
  // Optimistic UI Map: targetId -> isFollowing
  final Map<String, bool> _optimisticFollows = {};

  @override
  void initState() {
    super.initState();
    _fetchGuests(isInitial: true);
    // Refresh every 15 seconds for real-time feel
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchGuests());
    
    // Auto check-in when opening this tab
    ShopManager.instance.updatePresenceOnServer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchGuests({bool isInitial = false}) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    if (isInitial) setState(() => _isLoading = true);
    final myId = ShopManager.instance.currentUserId;
    
    final data = await ApiService.fetchActiveGuests(tenant.id, myId);
    if (mounted) {
      setState(() {
        if (data != null) _activeGuests = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _activeGuests;

    return RefreshIndicator(
      onRefresh: () => _fetchGuests(),
      color: const Color(0xFFFF5C00),
      backgroundColor: Colors.white,
      child: Container(
        color: const Color(0xFFF1F5F9),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // --- 1. PREMIUM MAP SECTION ---
            SliverToBoxAdapter(
              child: Container(
                height: 320, // Fixed height for map on scroll
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.05,
                          child: Image.network(
                            'https://www.transparenttextures.com/patterns/cubes.png',
                            repeat: ImageRepeat.repeat,
                          ),
                        ),
                      ),
                      Positioned(top: 40, left: 30, child: _buildFloorArea("Lounge Zone", 140, 110, Icons.weekend_rounded)),
                      Positioned(top: 40, right: 30, child: _buildFloorArea("Coffee Bar", 100, 160, Icons.local_cafe_rounded)),
                      Positioned(bottom: 50, left: 40, child: _buildFloorArea("Table Cluster", 80, 80, Icons.grid_view_rounded)),
                      Positioned(bottom: 50, right: 60, child: _buildFloorArea("Outdoor Patio", 90, 90, Icons.wb_sunny_rounded)),
  
                      if (users.isNotEmpty) Positioned(top: 70, left: 80, child: _buildMapPin(users[0])),
                      if (users.length > 1) Positioned(top: 130, right: 50, child: _buildMapPin(users[1])),
                      if (users.length > 2) Positioned(bottom: 65, left: 65, child: _buildMapPin(users[2])),
                      if (users.length > 3) Positioned(bottom: 65, right: 85, child: _buildMapPin(users[3])),
  
                      Positioned(
                        top: 16, left: 16, right: 16,
                        child: Row(
                          children: [
                            _buildMapActionBtn(Icons.settings_outlined, () => _showPrivacySettings(context)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                              child: Row(children: [
                                Text(TenantService().currentTenant.value?.name ?? "Downtown Hub", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), 
                                const Icon(Icons.keyboard_arrow_down, size: 16)
                              ]),
                            ),
                            const Spacer(),
                            _buildMapActionBtn(Icons.refresh, () => _fetchGuests(isInitial: true)),
                            const SizedBox(width: 8),
                            _buildMapActionBtn(Icons.chat_bubble_outline, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesListPage()))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
  
            // --- 2. PEOPLE LIST SECTION ---
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Active Now", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                            child: Row(children: [const CircleAvatar(radius: 3, backgroundColor: Colors.green), const SizedBox(width: 6), Text("${users.length} Live", style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))]),
                          ),
                        ],
                      ),
                    ),
                    
                    // Visibility Warning Message
                    ValueListenableBuilder<bool>(
                      valueListenable: ShopManager.instance.isProfileVisible,
                      builder: (context, isVisible, _) {
                        if (isVisible) return const SizedBox.shrink();
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[100]!),
                          ),
                          child: Text(
                            "तपाईंको प्रोफाइल सार्वजनिक रूपमा कसैलाई पनि देखिरहेको छैन। अरूलाई देखाउनको लागि सेटिङमा गई 'Public Profile' अन गर्नुहोस्।",
                            style: TextStyle(color: Colors.red[700], fontSize: 11, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
  
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
  
            // List of Users
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00))))
            else if (users.isEmpty)
              const SliverFillRemaining(child: Center(child: Text("No guests nearby yet", style: TextStyle(color: Colors.grey))))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Container(color: Colors.white, child: _buildUserListTile(users[index])),
                  childCount: users.length,
                ),
              ),
              
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorArea(String label, double width, double height, IconData icon) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFCBD5E1), size: 24),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMapPin(Map<String, dynamic> user) {
    String displayName = user['user_name'] ?? 'Guest';
    if (displayName == '0' || displayName.isEmpty || displayName == 'null') {
       String uidStr = user['user_id']?.toString() ?? '0000';
       displayName = "Diner ${uidStr.length >= 4 ? uidStr.substring(uidStr.length - 4) : uidStr}";
    }
    final String displayImage = user['gender'] == 'Female'
        ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
        : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
          child: CircleAvatar(radius: 20, backgroundImage: NetworkImage(displayImage)),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
          child: Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildMapActionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildUserListTile(Map<String, dynamic> user) {
    String displayName = user['user_name'] ?? 'Guest';
    if (displayName == '0' || displayName.isEmpty || displayName == 'null') {
       String uidStr = user['user_id']?.toString() ?? '0000';
       displayName = "Diner ${uidStr.length >= 4 ? uidStr.substring(uidStr.length - 4) : uidStr}";
    }
    final String displayLocation = "Table ${user['table_number']}";
    final String displayImage = user['gender'] == 'Female'
        ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
        : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg';
    final String targetId = user['user_id']?.toString() ?? '';
    
    bool isFollowing = _optimisticFollows.containsKey(targetId) 
        ? _optimisticFollows[targetId]! 
        : (user['is_following'] ?? 0) > 0;
    bool isFriend = isFollowing && (user['follows_me'] ?? 0) > 0;
    
    final myId = ShopManager.instance.currentUserId;
    final bool isMe = targetId == myId;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserProfileViewPage(userId: targetId, name: displayName)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(radius: 28, backgroundImage: NetworkImage(displayImage)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName + (isMe ? " (You)" : ""), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text("Dining at $displayLocation", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            if (!isMe)
              Row(
                children: [
                  _buildSocialIcon(
                    Icons.chat_bubble_outline_rounded, 
                    isFriend ? Colors.green : Colors.grey, 
                    () {
                      if (!isFriend) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Follow back to unlock messaging!")));
                        return;
                      }
                    }
                  ),
                  const SizedBox(width: 10),
                  
                  // Wave Icon (Visible only if target user allows it)
                  if (user['allow_waves'] == 1 || user['allow_waves'] == true)
                    _buildSocialIcon(Icons.back_hand_rounded, Colors.amber, () async {
                       final tenant = TenantService().currentTenant.value;
                       if (tenant != null && myId.isNotEmpty) {
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Waving at $displayName..."), duration: const Duration(milliseconds: 500)));
                         final success = await ApiService.sendWave(tenantId: tenant.id, myId: myId, targetId: targetId);
                         if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Waved at $displayName!"), duration: const Duration(seconds: 1)));
                         }
                       }
                    }),

                  const SizedBox(width: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (_loadingFollowIds.contains(targetId)) return;
                        
                        // Check if user is public before following
                        if (user['is_public'] == 0 || user['is_public'] == false) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text("तपाईं यो निजी प्रोफाइल (Private Profile) लाई पछ्याउन सक्नुहुन्न।"), backgroundColor: Colors.red),
                           );
                           return;
                        }

                        setState(() {
                          _optimisticFollows[targetId] = !isFollowing;
                          _loadingFollowIds.add(targetId);
                        });
                        final success = await ShopManager.instance.toggleFollow(targetId);
                        if (success) {
                          await _fetchGuests();
                        } else {
                          setState(() => _optimisticFollows.remove(targetId));
                        }
                        if (mounted) setState(() => _loadingFollowIds.remove(targetId));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isFollowing ? const Color(0xFFF1F5F9) : const Color(0xFFFF5C00),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _loadingFollowIds.contains(targetId)
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              isFollowing ? "Following" : "Follow",
                              style: TextStyle(color: isFollowing ? Colors.black87 : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Nearby Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              // Public Profile Switch
              ValueListenableBuilder<bool>(
                valueListenable: ShopManager.instance.isProfileVisible,
                builder: (context, isVisible, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingRow(
                      Icons.visibility_outlined, 
                      "Public Profile", 
                      "Show your location to other guests",
                      isVisible,
                      (v) {
                        ShopManager.instance.isProfileVisible.value = v;
                        ShopManager.instance.updatePrivacyOnServer();
                      }
                    ),
                    if (!isVisible)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 40),
                        child: Text(
                          "तपाईंको प्रोफाइल लुकेको छ। सार्वजनिक रूपमा देखाउनको लागि यसलाई अन गर्नुहोस्।",
                          style: TextStyle(color: Colors.red[700], fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Allow Waves Switch
              ValueListenableBuilder<bool>(
                valueListenable: ShopManager.instance.isWaveEnabled,
                builder: (context, canWave, _) => _buildSettingRow(
                  Icons.back_hand_outlined, 
                  "Allow Waves", 
                  "Let people greet you digitally",
                  canWave,
                  (v) {
                    ShopManager.instance.isWaveEnabled.value = v;
                    ShopManager.instance.updatePrivacyOnServer();
                  }
                ),
              ),
  
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Done"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String title, String sub, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Icon(icon, color: value ? const Color(0xFFFF5C00) : Colors.grey),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12))])),
        Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFFF5C00)),
      ],
    );
  }
}
