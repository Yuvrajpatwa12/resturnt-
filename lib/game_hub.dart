import 'package:flutter/material.dart';
import 'game.dart';
import 'cart_manager.dart';
import 'web_game_page.dart';
import 'tap_war_page.dart';

class GameHubPage extends StatefulWidget {
  const GameHubPage({super.key});

  @override
  State<GameHubPage> createState() => _GameHubPageState();
}

class _GameHubPageState extends State<GameHubPage> {
  int _hubIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: _buildHubBody(),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildHubNavItem(Icons.home, "Home", 0),
            _buildHubNavItem(Icons.grid_view_rounded, "Library", 1),
            _buildHubNavItem(Icons.person, "Profile", 2),
          ],
        ),
      ),
    );
  }

  Widget _buildHubNavItem(IconData icon, String label, int index) {
    bool isSelected = _hubIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _hubIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? const Color(0xFF4A68FF) : Colors.grey[400], size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF4A68FF) : Colors.grey[400],
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(color: Color(0xFF4A68FF), shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  Widget _buildHubBody() {
    switch (_hubIndex) {
      case 0: return _buildHubHome();
      case 1: return _buildHubLibrary();
      case 2: return _buildHubProfile();
      default: return _buildHubHome();
    }
  }

  // --- TAB 1: HUB HOME ---
  Widget _buildHubHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Profile & Coins
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=500&auto=format&fit=crop&q=60'),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Hello,", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text("@littlebear0213", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.monetization_on, color: Colors.orange, size: 18),
                    SizedBox(width: 4),
                    Text("1.500", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // --- TAP WAR LIVE BANNER ---
          _buildLiveBattleBanner(),
          const SizedBox(height: 32),

          const Text("Statistics", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          Row(
            children: [
              _buildStatCard("Level", "1.500", const Color(0xFF6236FF), Icons.emoji_events),
              const SizedBox(width: 16),
              ValueListenableBuilder<Duration>(
                valueListenable: ShopManager.instance.totalGameTime,
                builder: (context, duration, child) {
                  String timeStr = "${duration.inHours}h ${duration.inMinutes.remainder(60)}m";
                  return _buildStatCard("Time", timeStr, const Color(0xFFC4D600), Icons.timer);
                },
              ),
            ],
          ),
          const SizedBox(height: 32),

          const Text("Recommended games", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // Categories
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip("Survival", Icons.star, true),
                _buildCategoryChip("Action", Icons.local_fire_department, false),
                _buildCategoryChip("Collector", Icons.apps, false),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recommended Card
          _buildRecommendedGameCard(
            "2048 Puzzle",
            "99%",
            "1.2M",
            Colors.orange,
            Icons.grid_4x4,
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WebGamePage(gameTitle: "2048", gameUrl: "https://2048game.com/"))),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: HUB LIBRARY ---
  Widget _buildHubLibrary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recommended games", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildCategoryChip("Survival", Icons.star, true),
              _buildCategoryChip("Action", Icons.local_fire_department, false),
              _buildCategoryChip("Collector", Icons.apps, false),
            ],
          ),
          const SizedBox(height: 24),
          const Center(child: Text("↓ More popular above", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 0.8,
            children: [
              _buildLibraryItem("2048 Puzzle", "99%", "1.2M", Colors.orange, Icons.grid_4x4, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WebGamePage(gameTitle: "2048", gameUrl: "https://2048game.com/")));
              }),
              _buildLibraryItem("Hextris", "95%", "850K", Colors.blue, Icons.hexagon, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WebGamePage(gameTitle: "Hextris", gameUrl: "https://hextris.github.io/")));
              }),
              _buildLibraryItem("Snake Game", "98%", "2.1M", Colors.green, Icons.keyboard_arrow_right, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WebGamePage(gameTitle: "Snake", gameUrl: "https://playsnake.org/")));
              }),
              _buildLibraryItem("Burger Catcher", "87%", "315K", Colors.red, Icons.lunch_dining, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GamePage()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 3: HUB PROFILE ---
  Widget _buildHubProfile() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Banner & Avatar
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1614850523296-d8c1af93d400?w=800&auto=format&fit=crop&q=60'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const CircleAvatar(
                    radius: 46,
                    backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=500&auto=format&fit=crop&q=60'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),

          const Text("GAMER_NZ", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("littlebear0213", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),

          // Coins Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A68FF),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: const Color(0xFF4A68FF).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.monetization_on, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text("1.500", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(width: 16),
                Text("How to earn coins?", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Profile Stats Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ValueListenableBuilder<Duration>(
              valueListenable: ShopManager.instance.totalGameTime,
              builder: (context, duration, child) {
                String timeStr = "${duration.inHours}h ${duration.inMinutes.remainder(60)}m";
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.2,
                  children: [
                    _buildProfileStatBox(Icons.emoji_events, "Level", "14", Colors.green),
                    _buildProfileStatBox(Icons.timer, "Time", timeStr, Colors.blue),
                    _buildProfileStatBox(Icons.colorize, "Skills", "1.500", Colors.pink),
                    _buildProfileStatBox(Icons.videogame_asset, "Games", "28", Colors.orange),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Recommended games", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildCategoryChip("Survival", Icons.star, true),
                _buildCategoryChip("Action", Icons.local_fire_department, false),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Icon(icon, color: isSelected ? Colors.pink : Colors.orange, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRecommendedGameCard(String title, String rating, String players, Color color, IconData icon, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.thumb_up, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(rating, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.visibility, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(players, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A68FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text("Play", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryItem(String title, String rating, String players, Color color, IconData icon, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, color: color, size: 40),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.thumb_up, size: 10, color: Colors.grey),
              const SizedBox(width: 2),
              Text(rating, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              const SizedBox(width: 8),
              const Icon(Icons.visibility, size: 10, color: Colors.grey),
              const SizedBox(width: 2),
              Text(players, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A68FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: const Text("Play", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatBox(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBattleBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5C00), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF5C00).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text("LIVE BATTLE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              const Icon(Icons.flash_on, color: Colors.amber, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "HALL TAP WAR!",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const Text(
            "Every table is competing. Can you tap the fastest?",
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ShopManager.instance.startTapWar();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TapWarPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF5C00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("JOIN THE WAR 🔥", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
