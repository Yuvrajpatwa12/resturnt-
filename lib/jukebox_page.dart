import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'music_poll_widget.dart';
import 'create_poll_page.dart';

class JukeboxPage extends StatefulWidget {
  const JukeboxPage({super.key});

  @override
  State<JukeboxPage> createState() => _JukeboxPageState();
}

class _JukeboxPageState extends State<JukeboxPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dedicationController = TextEditingController();
  late AnimationController _visualizerController;

  @override
  void initState() {
    super.initState();
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    // Refresh live music queue when Jukebox page loads
    ShopManager.instance.refreshMusicStatus();
  }

  @override
  void dispose() {
    _visualizerController.dispose();
    _searchController.dispose();
    _dedicationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: ShopManager.instance.currentSong,
      builder: (context, song, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFAF0), Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildPoll(),
                          const SizedBox(height: 10),
                          _buildAlbumArt(song),
                          const SizedBox(height: 24),
                          _buildDedication(song),
                          const SizedBox(height: 32),
                          _buildSongInfo(song),
                          const SizedBox(height: 40),
                          _buildVisualizer(),
                          const SizedBox(height: 30),
                          _buildProgress(song),
                          const SizedBox(height: 40),
                          _buildQueue(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black87, size: 32), onPressed: () => Navigator.pop(context)),
          Column(
            children: [
              const Text("COMMUNITY JUKEBOX", style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 4),
              ValueListenableBuilder<int>(
                valueListenable: ShopManager.instance.vibeScore,
                builder: (context, score, child) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFF5C00).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text("VIBE SCORE: $score%", style: const TextStyle(color: Color(0xFFFF5C00), fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.more_vert_rounded, color: Colors.black87), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePollPage()))),
        ],
      ),
    );
  }

  Widget _buildPoll() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: ShopManager.instance.activePoll,
      builder: (context, poll, child) {
        if (poll == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: MusicPollWidget(pollData: poll),
        );
      },
    );
  }

  Widget _buildAlbumArt(Map<String, dynamic> song) {
    final imageUrl = song['image'] ?? '';

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF5C00).withValues(alpha: 0.15),
            ),
          ),
          Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF5C00).withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 5),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Icon(Icons.music_note_rounded, size: 80, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDedication(Map<String, dynamic> song) {
    final dedication = song['dedication'];
    if (dedication == null || dedication.toString().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_rounded, color: Colors.red, size: 14),
          const SizedBox(width: 8),
          Text(dedication.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _buildSongInfo(Map<String, dynamic> song) {
    return Column(
      children: [
        Text(song['title'] ?? "No Song Playing", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black)),
        const SizedBox(height: 6),
        Text(song['artist'] ?? "Select a song from queue below", style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildVisualizer() {
    return AnimatedBuilder(
      animation: _visualizerController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (index) {
            final double height = 10 + (index % 3 == 0 ? _visualizerController.value * 25 : (1 - _visualizerController.value) * 20);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 4, height: height,
              decoration: BoxDecoration(color: const Color(0xFFFF5C00), borderRadius: BorderRadius.circular(2)),
            );
          }),
        );
      },
    );
  }

  Widget _buildProgress(Map<String, dynamic> song) {
    final double progress = double.tryParse(song['progress']?.toString() ?? '0.3') ?? 0.3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: const Color(0xFFFF5C00),
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFFFF5C00),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayColor: const Color(0xFFFF5C00).withValues(alpha: 0.1),
            ),
            child: Slider(value: progress, onChanged: (v) {}),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("1:12", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                Text("3:45", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueue() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, -10))],
      ),
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Up Next 🗳️", style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showRequestModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Request", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: ShopManager.instance.musicQueue,
            builder: (context, queue, child) {
              final activeQueue = queue.where((item) {
                final st = (item['status'] ?? 'queued').toString().toLowerCase().trim();
                return st != 'deleted';
              }).toList();

              activeQueue.sort((a, b) {
                final int vA = int.tryParse(a['votes']?.toString() ?? '0') ?? 0;
                final int vB = int.tryParse(b['votes']?.toString() ?? '0') ?? 0;
                return vB.compareTo(vA);
              });

              if (activeQueue.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text("No song requests active. Tap 'Request' above!", style: TextStyle(color: Colors.grey)),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeQueue.length,
                itemBuilder: (context, index) {
                  final item = activeQueue[index];
                  int songId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
                  if (songId == 0) return const SizedBox.shrink();
                  bool userLiked = item['user_liked'] == true;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 55, height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              item['image'] ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.music_note, color: Colors.grey)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['title'] ?? "Untitled", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(item['artist'] ?? "Unknown Artist", style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final res = await ShopManager.instance.toggleMusicVote(songId);
                            if (res['success'] == false && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(res['message']), backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: userLiked ? Colors.red.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  userLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: userLiked ? Colors.red : const Color(0xFF64748B),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  (item['votes'] ?? 0).toString(),
                                  style: TextStyle(
                                    color: userLiked ? Colors.red : const Color(0xFF64748B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRequestModal() {
    _searchController.clear();
    _dedicationController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Request a Song", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Song title...",
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dedicationController,
              decoration: InputDecoration(
                hintText: "Special message / dedication (optional)...",
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_searchController.text.trim().isEmpty) return;
                  final title = _searchController.text.trim();
                  final dedication = _dedicationController.text.trim();

                  Navigator.pop(context);
                  final res = await ShopManager.instance.requestSong(title, "Requested", dedication.isNotEmpty ? dedication : null);
                  if (res['success'] == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Song Requested Successfully! 🔥"), backgroundColor: Color(0xFFFF5C00)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("SUBMIT REQUEST", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
