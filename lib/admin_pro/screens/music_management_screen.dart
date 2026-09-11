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

class _MusicManagementScreenState extends State<MusicManagementScreen> {
  Timer? _poller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _poller = Timer.periodic(const Duration(seconds: 10), (t) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ShopManager.instance.refreshMusicStatus();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _setNowPlaying(Map<String, dynamic> song, {int? queueId}) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final success = await ApiService.adminSetNowPlaying({
      'tenant_id': tenant.id,
      'title': song['title'],
      'artist': song['artist'],
      'image': song['image'],
      'dedication': song['dedication'],
      'queue_id': queueId,
    });

    if (success && mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playlist Updated!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Now Playing (Broadcasting)"),
                const SizedBox(height: 16),
                _buildActiveSongCard(),
                const SizedBox(height: 40),
                _buildSectionHeader("Live User Requests & Voting"),
                const SizedBox(height: 16),
                _buildQueueList(),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5));
  }

  Widget _buildActiveSongCard() {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: ShopManager.instance.currentSong,
      builder: (context, song, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AdminTheme.softShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(song['image'] ?? '', width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200], child: const Icon(Icons.music_note))),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song['title'] ?? 'No Song Playing', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(song['artist'] ?? 'Select from queue below', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.graphic_eq_rounded, color: AdminTheme.royalBlue),
            ],
          ),
        );
      }
    );
  }

  Widget _buildQueueList() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.musicQueue,
      builder: (context, queue, _) {
        if (queue.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(Icons.music_off_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("No active requests from users.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: queue.length,
          itemBuilder: (context, index) {
            final item = queue[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AdminTheme.softShadow,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(item['image'] ?? '', width: 50, height: 50, fit: BoxFit.cover),
                ),
                title: Text(item['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${item['artist']} • ${item['votes']} Votes", style: const TextStyle(fontSize: 12)),
                    if (item['dedication'] != null)
                      Text("❤️ ${item['dedication']}", style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Colors.green, size: 32),
                      onPressed: () => _setNowPlaying(item, queueId: int.tryParse(item['id']?.toString() ?? '')),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                      onPressed: () async {
                        final tenant = TenantService().currentTenant.value;
                        final songId = int.tryParse(item['id']?.toString() ?? '');
                        if (tenant != null && songId != null) {
                          await ApiService.adminDeleteQueue(tenant.id, songId);
                          _refresh();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }
}
