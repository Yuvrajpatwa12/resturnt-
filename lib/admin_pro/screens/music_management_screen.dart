import 'package:flutter/material.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';
import 'dart:async';

class MusicManagementScreen extends StatefulWidget {
  const MusicManagementScreen({super.key});

  @override
  State<MusicManagementScreen> createState() => _MusicManagementScreenState();
}

class _MusicManagementScreenState extends State<MusicManagementScreen> with SingleTickerProviderStateMixin {
  Timer? _poller;
  Timer? _playbackTimer;
  late AnimationController _visualizerController;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isSongEnded = false; // Indicates current song reached duration end
  int _elapsedSeconds = 0;
  int _songDurationSeconds = 180; // Default 3 minutes duration
  int? _currentQueueId;
  String _activeTitle = 'No Song Playing';
  String _activeArtist = 'Select top voted song from queue below';
  String _activeImage = '';

  @override
  void initState() {
    super.initState();
    // Animation controller for animated music visualizer
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    // Fast 3-second real-time database poller for live votes & requests
    _poller = Timer.periodic(const Duration(seconds: 3), (t) => _refresh());
    _refresh();

    // Start playback timer
    _startPlaybackTimer();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _playbackTimer?.cancel();
    _visualizerController.dispose();
    super.dispose();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isPlaying && mounted) {
        setState(() {
          _elapsedSeconds++;
          if (_elapsedSeconds >= _songDurationSeconds) {
            _onSongTimerEnded();
          }
        });
      }
    });
  }

  Future<void> _refresh() async {
    await ShopManager.instance.refreshMusicStatus();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _setNowPlaying(Map<String, dynamic> song, {int? queueId}) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';
    final qId = queueId ?? int.tryParse(song['id']?.toString() ?? '');
    final sTitle = song['title'] ?? 'Unknown Title';
    final sArtist = song['artist'] ?? 'Requested';
    final sImage = song['image'] ?? '';

    // 1. Immediately update local state so the top "Now Playing" card updates INSTANTLY!
    setState(() {
      _currentQueueId = qId;
      _elapsedSeconds = 0;
      _isPlaying = true;
      _isSongEnded = false;
      _activeTitle = sTitle;
      _activeArtist = sArtist;
      _activeImage = sImage;
    });

    ShopManager.instance.currentSong.value = {
      'title': sTitle,
      'artist': sArtist,
      'image': sImage,
      'dedication': song['dedication'] ?? '',
    };

    // 2. Send API broadcast to backend server
    await ApiService.adminSetNowPlaying({
      'tenant_id': tenantId,
      'title': sTitle,
      'artist': sArtist,
      'image': sImage,
      'dedication': song['dedication'] ?? '',
      'queue_id': qId,
    });

    if (mounted) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Now Broadcasting: $sTitle"),
            backgroundColor: AdminTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Triggered when the song duration timer reaches the end
  void _onSongTimerEnded() {
    setState(() {
      _isPlaying = false;
      _isSongEnded = true;
    });
  }

  // Admin plays next song
  Future<void> _playNextSong() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

    setState(() {
      _isPlaying = false;
      _isSongEnded = false;
      _elapsedSeconds = 0;
      _currentQueueId = null;
      _activeTitle = 'No Song Playing';
      _activeArtist = 'Select top voted song from queue below';
      _activeImage = '';
    });

    await _refresh();

    // Auto-play next top voted song if available
    final remainingQueue = List<Map<String, dynamic>>.from(ShopManager.instance.musicQueue.value).where((item) {
      final st = (item['status'] ?? 'queued').toString().toLowerCase().trim();
      return st != 'deleted';
    }).toList();

    if (remainingQueue.isNotEmpty) {
      remainingQueue.sort((a, b) {
        final int vA = int.tryParse(a['votes']?.toString() ?? '0') ?? 0;
        final int vB = int.tryParse(b['votes']?.toString() ?? '0') ?? 0;
        return vB.compareTo(vA);
      });

      final nextTop = remainingQueue.first;
      final nextQId = int.tryParse(nextTop['id']?.toString() ?? '');
      await _setNowPlaying(nextTop, queueId: nextQId);
    } else {
      // Reset now playing if queue is empty
      ShopManager.instance.currentSong.value = {
        'title': 'No Song Playing',
        'artist': 'Select top voted song from queue below',
        'image': '',
        'dedication': '',
      };
      await ApiService.adminSetNowPlaying({
        'tenant_id': tenantId,
        'title': 'No Song Playing',
        'artist': 'Select top voted song from queue below',
        'image': '',
        'dedication': '',
      });
      _refresh();
    }
  }

  String _formatTime(int totalSecs) {
    final mins = (totalSecs / 60).floor();
    final secs = totalSecs % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminTheme.royalBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Live Jukebox Control", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                          Text("Real-time song requests & animated broadcasting control", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      IconButton(
                        onPressed: _refresh,
                        icon: const Icon(Icons.sync_rounded, color: AdminTheme.royalBlue),
                        tooltip: "Sync Live Queue",
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader("Now Playing (Broadcasting)"),
                  const SizedBox(height: 12),
                  _buildActiveSongCard(),
                  const SizedBox(height: 32),

                  _buildSectionHeader("Live User Requests & Voting Queue"),
                  const SizedBox(height: 12),
                  _buildQueueList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    );
  }

  Widget _buildActiveSongCard() {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: ShopManager.instance.currentSong,
      builder: (context, song, _) {
        final title = (_isPlaying || _isSongEnded) ? _activeTitle : (song['title'] ?? 'No Song Playing');
        final artist = (_isPlaying || _isSongEnded) ? _activeArtist : (song['artist'] ?? 'Select top voted song from queue below');
        final image = (_isPlaying || _isSongEnded) ? _activeImage : (song['image'] ?? '');
        final double progress = _songDurationSeconds > 0 ? (_elapsedSeconds / _songDurationSeconds).clamp(0.0, 1.0) : 0.0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AdminTheme.softShadow,
            border: Border.all(
              color: _isSongEnded
                  ? Colors.amber.shade700
                  : (_isPlaying ? AdminTheme.royalBlue : Colors.grey.shade200),
              width: _isSongEnded ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Thumbnail & Visualizer Overlay
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          image,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 80,
                            height: 80,
                            color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                            child: const Icon(Icons.music_note_rounded, color: AdminTheme.royalBlue, size: 36),
                          ),
                        ),
                      ),
                      if (_isPlaying)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _buildEqualizerAnimation(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),

                  // Song Info & Live Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isSongEnded
                                    ? Colors.amber.shade100
                                    : (_isPlaying ? Colors.redAccent.withValues(alpha: 0.1) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isSongEnded ? Icons.warning_amber_rounded : Icons.sensors,
                                    size: 12,
                                    color: _isSongEnded ? Colors.amber.shade900 : (_isPlaying ? Colors.redAccent : Colors.grey),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isSongEnded
                                        ? "SONG FINISHED — MANUAL PLAY REQUIRED"
                                        : (_isPlaying ? "LIVE BROADCASTING" : "STANDBY"),
                                    style: TextStyle(
                                      color: _isSongEnded ? Colors.amber.shade900 : (_isPlaying ? Colors.redAccent : Colors.grey),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                        const SizedBox(height: 2),
                        Text(artist, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),

                  // Controls (Play/Pause or Delete & Play Next Button)
                  if (_isSongEnded)
                    ElevatedButton.icon(
                      onPressed: _playNextSong,
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 18),
                      label: const Text("PLAY NEXT SONG"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.royalBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    )
                  else
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            color: AdminTheme.royalBlue,
                            size: 40,
                          ),
                          onPressed: () {
                            setState(() => _isPlaying = !_isPlaying);
                          },
                          tooltip: _isPlaying ? "Pause" : "Resume",
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.orange, size: 32),
                          onPressed: _playNextSong,
                          tooltip: "Play Next Song",
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Playback Duration Progress Bar & Presets
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_formatTime(_elapsedSeconds)} / ${_formatTime(_songDurationSeconds)}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isSongEnded ? Colors.amber.shade900 : AdminTheme.royalBlue,
                        ),
                      ),
                      // Duration Presets
                      Row(
                        children: [1, 2, 3, 5].map((mins) {
                          final secs = mins * 60;
                          final isSelected = _songDurationSeconds == secs;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () => setState(() => _songDurationSeconds = secs),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? AdminTheme.royalBlue : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "${mins}m",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isSongEnded ? Colors.amber.shade700 : AdminTheme.royalBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEqualizerAnimation() {
    return AnimatedBuilder(
      animation: _visualizerController,
      builder: (context, child) {
        final val = _visualizerController.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBar(12 + (val * 24)),
            _buildBar(28 - (val * 18)),
            _buildBar(8 + (val * 32)),
            _buildBar(22 - (val * 14)),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 4,
      height: height.clamp(4.0, 36.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildQueueList() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.musicQueue,
      builder: (context, queue, _) {
        // Filter out deleted songs so all active/queued requests in database are displayed
        final activeQueue = queue.where((item) {
          final st = (item['status'] ?? 'queued').toString().toLowerCase().trim();
          return st != 'deleted';
        }).toList();

        if (activeQueue.isEmpty) {
          return ValueListenableBuilder<String>(
            valueListenable: ShopManager.instance.musicApiStatusMessage,
            builder: (context, statusMsg, _) {
              final isError = statusMsg.toLowerCase().contains('error');

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AdminTheme.softShadow,
                  border: Border.all(
                    color: isError ? Colors.red.shade200 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isError ? Icons.error_outline_rounded : Icons.music_off_outlined,
                      size: 48,
                      color: isError ? Colors.redAccent : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isError ? "Connection / Server Diagnostic" : "No active song requests right now.",
                      style: TextStyle(
                        color: isError ? Colors.redAccent : Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isError ? Colors.red.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusMsg,
                        style: TextStyle(
                          color: isError ? Colors.red.shade900 : Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => ShopManager.instance.refreshMusicStatus(),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text("RELOAD QUEUE"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.royalBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final res = await ShopManager.instance.requestSong("Chhiyaa Special", "Live Mix", "Test Request");
                            if (res['success'] == true) {
                              ShopManager.instance.refreshMusicStatus();
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text("ADD TEST REQUEST"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminTheme.royalBlue,
                            side: const BorderSide(color: AdminTheme.royalBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        }

        // Sort active queue descending by votes count (Highest likes/votes first)
        final sortedQueue = List<Map<String, dynamic>>.from(activeQueue);
        sortedQueue.sort((a, b) {
          final int vA = int.tryParse(a['votes']?.toString() ?? '0') ?? 0;
          final int vB = int.tryParse(b['votes']?.toString() ?? '0') ?? 0;
          return vB.compareTo(vA);
        });

        final topSong = sortedQueue.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent "PLAY NEXT TOP VOTED SONG" Bar
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AdminTheme.royalBlue, AdminTheme.royalBlue.withValues(alpha: 0.85)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AdminTheme.softShadow,
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("NEXT UP (MOST VOTED)", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(
                          "${topSong['title']} • ${topSong['votes'] ?? 0} Likes",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final qId = int.tryParse(topSong['id']?.toString() ?? '');
                      _setNowPlaying(topSong, queueId: qId);
                    },
                    icon: const Icon(Icons.play_arrow_rounded, color: AdminTheme.royalBlue, size: 18),
                    label: const Text("PLAY TOP VOTED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AdminTheme.royalBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),

            // Queue List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedQueue.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = sortedQueue[index];
                final isTop = index == 0;
                final songId = int.tryParse(item['id']?.toString() ?? '');
                final votes = int.tryParse(item['votes']?.toString() ?? '0') ?? 0;
                final title = item['title'] ?? 'Untitled';
                final artist = item['artist'] ?? 'Requested';
                final dedication = item['dedication']?.toString();
                final requestedBy = item['requested_by']?.toString();

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AdminTheme.softShadow,
                    border: Border.all(
                      color: isTop ? Colors.amber : Colors.grey.shade200,
                      width: isTop ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Song Thumbnail
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              item['image'] ?? '',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey.shade100,
                                child: const Icon(Icons.music_note, color: Colors.grey),
                              ),
                            ),
                          ),
                          if (isTop)
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.star, color: Colors.white, size: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isTop)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "🔥 #1 MOST VOTED (NEXT IN LINE)",
                                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 9),
                                ),
                              ),
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.darkNavy)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(artist, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                if (requestedBy != null && requestedBy.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      " • By: $requestedBy",
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Likes / Votes badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.favorite, size: 12, color: Colors.redAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$votes Likes",
                                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (dedication != null && dedication.isNotEmpty && dedication != 'null') ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "💬 $dedication",
                                        style: TextStyle(color: Colors.purple.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: AdminTheme.emeraldGreen, size: 36),
                            tooltip: "Broadcast Song Now",
                            onPressed: () => _setNowPlaying(item, queueId: songId),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                            tooltip: "Remove from Queue",
                            onPressed: () {
                              if (songId != null && songId > 0) {
                                _confirmAndDeleteSong(context, item, songId, title);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmAndDeleteSong(BuildContext context, Map<String, dynamic> item, int songId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            const Text("Remove Song Request?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Are you sure you want to remove '$title' from the queue? This action cannot be undone.",
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final tenant = TenantService().currentTenant.value;
              final tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

              // Optimistically delete locally
              ShopManager.instance.markSongDeleted(songId);

              // Call backend API
              final success = await ApiService.adminDeleteQueue(tenantId, songId);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "'$title' deleted from queue." : "Deleted locally."),
                    backgroundColor: success ? Colors.redAccent : Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
              _refresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text("DELETE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
