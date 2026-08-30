import 'package:flutter/material.dart';
import 'cart_manager.dart';

class CreatePollPage extends StatefulWidget {
  const CreatePollPage({super.key});

  @override
  State<CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<CreatePollPage> {
  final TextEditingController _titleController = TextEditingController();
  final List<Map<String, dynamic>> _selectedSongs = [];

  // Mock songs library for selection
  final List<Map<String, dynamic>> _library = [
    {'title': 'Starboy', 'artist': 'The Weeknd', 'image': 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=200'},
    {'title': 'Save Your Tears', 'artist': 'The Weeknd', 'image': 'https://images.unsplash.com/photo-1619983081563-430f63602796?w=200'},
    {'title': 'Don\'t Start Now', 'artist': 'Dua Lipa', 'image': 'https://images.unsplash.com/photo-1493225255756-d9584f8606e9?w=200'},
    {'title': 'Shape of You', 'artist': 'Ed Sheeran', 'image': 'https://images.unsplash.com/photo-1459749411177-042180ce673c?w=200'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Launch Live Poll", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("POLL TITLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: "e.g. Next Party Track?",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            const Text("SELECT 2 SONGS TO BATTLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _library.length,
              itemBuilder: (context, index) {
                final song = _library[index];
                final isSelected = _selectedSongs.any((s) => s['title'] == song['title']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF9C1C24).withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? const Color(0xFF9C1C24) : Colors.grey[200]!),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(song['image'], width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    title: Text(song['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(song['artist'], style: const TextStyle(fontSize: 12)),
                    trailing: isSelected 
                      ? const Icon(Icons.check_circle, color: Color(0xFF9C1C24))
                      : const Icon(Icons.add_circle_outline, color: Colors.grey),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSongs.removeWhere((s) => s['title'] == song['title']);
                        } else if (_selectedSongs.length < 2) {
                          _selectedSongs.add(song);
                        }
                      });
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_titleController.text.isNotEmpty && _selectedSongs.length == 2)
                  ? () {
                      ShopManager.instance.createMusicPoll(_titleController.text, _selectedSongs);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Live Vote is now ACTIVE in the Jukebox! 🔥")),
                      );
                    }
                  : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C1C24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("LAUNCH VOTE NOW", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
