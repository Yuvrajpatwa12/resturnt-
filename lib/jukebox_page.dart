import 'dart:ui';
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
                  decoration: BoxDecoration(color: const Color(0xFFFF5C00).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
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
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: MusicPollWidget(pollData: poll));
      },
    );
  }

  Widget _buildAlbumArt(Map<String, dynamic> song) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.75,
      height: MediaQuery.of(context).size.width * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 40, offset: const Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Image.network(
          song['image'] ?? '',
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.music_note_rounded, size: 64, color: Color(0xFF94A3B8))),
        ),
      ),
    );
  }

  Widget _buildDedication(Map<String, dynamic> song) {
    if (song['dedication'] == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.favorite, color: Color(0xFFFF5C00), size: 14), const SizedBox(width: 8), Text(song['dedication'], style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _buildSongInfo(Map<String, dynamic> song) {
    return Column(children: [
      Text(song['title'] ?? "Unknown", style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      Text(song['artist'] ?? "Unknown Artist", style: const TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildVisualizer() {
    return AnimatedBuilder(
      animation: _visualizerController,
      builder: (context, child) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(20, (index) {
          double height = (index % 5 + 1) * 8.0 + (index % 3) * 4.0;
          return Container(
            width: 4, height: height + (_visualizerController.value * (index % 4 + 1) * 15),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: const LinearGradient(colors: [Color(0xFFFF5C00), Color(0xFFFFAB40)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          );
        }),
      ),
    );
  }

  Widget _buildProgress(Map<String, dynamic> song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: song['progress'] ?? 0.0, minHeight: 6, backgroundColor: const Color(0xFFE2E8F0), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5C00)))),
        const SizedBox(height: 12),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("1:42", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)), Text("3:54", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))]),
      ]),
    );
  }

  Widget _buildQueue() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -10))]),
      padding: const EdgeInsets.all(30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Up Next 🗳️", style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
          ElevatedButton.icon(onPressed: _showRequestModal, icon: const Icon(Icons.add, size: 16), label: const Text("Request", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C00), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16))),
        ]),
        const SizedBox(height: 24),
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: ShopManager.instance.musicQueue,
          builder: (context, queue, child) => ListView.builder(
            shrinkWrap: true, padding: EdgeInsets.zero, physics: const NeverScrollableScrollPhysics(), itemCount: queue.length,
            itemBuilder: (context, index) {
              final item = queue[index];
              bool hasVoted = item['hasVoted'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(children: [
                  Container(width: 55, height: 55, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(item['image'], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.music_note, color: Colors.grey))))),
                  const SizedBox(width: 15),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['title'] ?? "Untitled", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)), Text(item['artist'] ?? "Unknown Artist", style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))])),
                  GestureDetector(
                    onTap: () => ShopManager.instance.toggleMusicVote(index),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: hasVoted ? const Color(0xFFFF5C00) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(hasVoted ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: hasVoted ? Colors.white : const Color(0xFF64748B), size: 16), const SizedBox(width: 8), Text((item['votes'] ?? 0).toString(), style: TextStyle(color: hasVoted ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13))])),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showRequestModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text("Make a Request", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
              const SizedBox(height: 8),
              const Text("What should we play next?", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Song title or artist...",
                  prefixIcon: const Icon(Icons.music_note, color: Color(0xFFFF5C00)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5C00))),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dedicationController,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Dedicate to... (e.g. Table 12)",
                  prefixIcon: const Icon(Icons.favorite_border, color: Color(0xFFFF5C00)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5C00))),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      ShopManager.instance.requestSong(
                        _searchController.text, 
                        "Requested",
                        _dedicationController.text.isEmpty ? null : _dedicationController.text
                      );
                      _searchController.clear();
                      _dedicationController.clear();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Request sent! Earned +5 Vibe Score."),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color(0xFFFF5C00),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: const Text("SUBMIT REQUEST", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
