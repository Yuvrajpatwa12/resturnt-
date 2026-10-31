import 'package:flutter/material.dart';
import 'dart:async';
import 'services/api_service.dart';
import 'services/tenant_service.dart';
import 'cart_manager.dart';
import 'tap_war_page.dart';

class SquadLobbyPage extends StatefulWidget {
  final int squadId;
  final bool isHost;

  const SquadLobbyPage({
    super.key,
    required this.squadId,
    required this.isHost,
  });

  @override
  State<SquadLobbyPage> createState() => _SquadLobbyPageState();
}

class _SquadLobbyPageState extends State<SquadLobbyPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _squadData;
  List<Map<String, dynamic>> _members = [];
  Timer? _pollTimer;
  bool _startingGame = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    // Poll every 3 seconds as required by specification
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final myId = ShopManager.instance.currentUserId;

    final res = await ApiService.getSquadStatus(
      tenantId: tenant.id,
      squadId: widget.squadId,
      userId: myId,
    );

    if (res != null && res['status'] == 'success' && mounted) {
      final squad = res['squad'];
      final members = List<Map<String, dynamic>>.from(res['members'] ?? []);

      setState(() {
        _squadData = squad;
        _members = members;
        _isLoading = false;
      });

      // Check if game started or in progress
      final status = squad['status']?.toString().toLowerCase();
      if (status == 'inprogress' || status == 'ready') {
        _pollTimer?.cancel();
        // Transition to Multiplayer Tap War match screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TapWarMultiplayerPage(
              squadId: widget.squadId,
              startAt: squad['start_at'],
            ),
          ),
        );
      } else if (status == 'cancelled' || status == 'expired') {
        _pollTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Squad session closed or expired.")),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _startGame() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final myId = ShopManager.instance.currentUserId;

    setState(() => _startingGame = true);
    final res = await ApiService.startSquadGame(
      tenantId: tenant.id,
      userId: myId,
      squadId: widget.squadId,
    );

    if (res != null && res['status'] == 'success') {
      // Will be picked up by the next poll or immediate fetch
      _fetchStatus();
    } else {
      if (mounted) {
        setState(() => _startingGame = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? "Could not start game")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final joinedCount = _members.where((m) => m['status'] == 'Joined').length;
    final bool canStart = widget.isHost && joinedCount >= 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("Tap War Squad Lobby", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.sports_esports_rounded, size: 48, color: Colors.orange),
                        const SizedBox(height: 12),
                        const Text("Squad Battle Arena", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text("Squad ID: #${widget.squadId} • Table #${_squadData?['table_id'] ?? '-'}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Squad Members", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                        child: Text("$joinedCount / 4 Joined", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final m = _members[index];
                        final status = m['status'] ?? 'Invited';
                        Color statusColor = Colors.orange;
                        if (status == 'Joined') statusColor = Colors.green;
                        if (status == 'Declined' || status == 'Left') statusColor = Colors.red;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                child: Text(m['user_name']?[0]?.toUpperCase() ?? 'U', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m['user_name'] ?? 'Diner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(m['user_id'] == _squadData?['created_by_user_id'] ? 'Squad Host' : 'Member', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.isHost)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (!canStart || _startingGame) ? null : _startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _startingGame
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                joinedCount < 2 ? "Waiting for players (Need ≥2)..." : "START SQUAD BATTLE 🚀",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    )
                  else
                    const Center(
                      child: Text(
                        "Waiting for host to start the battle...",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
