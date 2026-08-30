import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'chat_page.dart';
import 'messages_list_page.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  @override
  Widget build(BuildContext context) {
    final users = ShopManager.instance.nearbyUsers;

    return Container(
      color: const Color(0xFFF1F5F9), // Light grey base
      child: Column(
        children: [
          // --- 1. PREMIUM MAP SECTION ---
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  children: [
                    // Blueprint Grid Pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.05,
                        child: Image.network(
                          'https://www.transparenttextures.com/patterns/cubes.png',
                          repeat: ImageRepeat.repeat,
                        ),
                      ),
                    ),

                    // --- Stylized Areas ---
                    Positioned(top: 40, left: 30, child: _buildFloorArea("Lounge Zone", 140, 110, Icons.weekend_rounded)),
                    Positioned(top: 40, right: 30, child: _buildFloorArea("Coffee Bar", 100, 160, Icons.local_cafe_rounded)),
                    Positioned(bottom: 50, left: 40, child: _buildFloorArea("Table Cluster", 80, 80, Icons.grid_view_rounded)),
                    Positioned(bottom: 50, right: 60, child: _buildFloorArea("Outdoor Patio", 90, 90, Icons.wb_sunny_rounded)),

                    // --- User Pins ---
                    Positioned(top: 70, left: 80, child: _buildMapPin(users[0])),
                    Positioned(top: 130, right: 50, child: _buildMapPin(users[1])),
                    Positioned(bottom: 65, left: 65, child: _buildMapPin(users[2])),
                    Positioned(bottom: 65, right: 85, child: _buildMapPin(users[3])),

                    // Top Bar UI over Map
                    Positioned(
                      top: 16, left: 16, right: 16,
                      child: Row(
                        children: [
                          _buildMapActionBtn(Icons.settings_outlined, () => _showPrivacySettings(context)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                            child: const Row(children: [Text("Downtown Hub", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Icon(Icons.keyboard_arrow_down, size: 16)]),
                          ),
                          const Spacer(),
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
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Active Now", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Row(children: [CircleAvatar(radius: 3, backgroundColor: Colors.green), SizedBox(width: 6), Text("4 Live", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: users.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _buildUserListTile(user);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
          child: CircleAvatar(radius: 20, backgroundImage: NetworkImage(user['image'])),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
          child: Text(user['name'], style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildMapActionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildUserListTile(Map<String, dynamic> user) {
    bool isFollowing = user['isFollowing'] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          CircleAvatar(radius: 28, backgroundImage: NetworkImage(user['image'])),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text("${user['location']} • ${user['distance']}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          Row(
            children: [
              _buildSocialIcon(Icons.back_hand_rounded, Colors.amber, () {}),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => user['isFollowing'] = !isFollowing),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFollowing ? const Color(0xFFF1F5F9) : const Color(0xFFFF5C00),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isFollowing ? "Following" : "Follow",
                    style: TextStyle(color: isFollowing ? Colors.black87 : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Nearby Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildSettingRow(Icons.visibility_off_outlined, "Incognito Mode", "Hide your location from others"),
            const SizedBox(height: 20),
            _buildSettingRow(Icons.back_hand_outlined, "Allow Waves", "Let people greet you digitally"),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Save Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String title, String sub) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12))])),
        Switch(value: true, onChanged: (v) {}, activeColor: const Color(0xFFFF5C00)),
      ],
    );
  }
}
