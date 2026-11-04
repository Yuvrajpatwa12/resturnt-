import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/tenant_service.dart';
import '../squad_lobby_page.dart';

class BattlegroundBrowser extends StatefulWidget {
  const BattlegroundBrowser({super.key});

  @override
  State<BattlegroundBrowser> createState() => _BattlegroundBrowserState();
}

class _BattlegroundBrowserState extends State<BattlegroundBrowser> {
  List<Map<String, dynamic>> _battlegrounds = [];
  final Set<int> _joiningSquads = {};
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBattlegrounds();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadBattlegrounds(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBattlegrounds() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final result = await ApiService.getOpenBattlegrounds(tenantId: tenant.id);
    if (!mounted) return;
    setState(() {
      if (result != null) _battlegrounds = result;
      _isLoading = false;
    });
  }

  Future<void> _requestToJoin(int squadId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || !_joiningSquads.add(squadId)) return;
    setState(() {});

    final response = await ApiService.requestBattlegroundJoin(
      tenantId: tenant.id,
      squadId: squadId,
    );
    if (!mounted) return;
    setState(() {
      _joiningSquads.remove(squadId);
      if (response?['status'] == 'success') {
        final index = _battlegrounds.indexWhere(
          (item) => item['squad_id'].toString() == squadId.toString(),
        );
        if (index >= 0) {
          _battlegrounds[index]['member_status'] = 'JoinRequested';
          _battlegrounds[index]['joined_count'] =
              (int.tryParse(_battlegrounds[index]['joined_count'].toString()) ??
                  0) +
              1;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response?['message']?.toString() ??
              'Could not send join request. Please try again.',
        ),
      ),
    );
  }

  Future<void> _openLobby(int squadId, bool isHost) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SquadLobbyPage(squadId: squadId, isHost: isHost),
      ),
    );
    _loadBattlegrounds();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Open Battlegrounds',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadBattlegrounds,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_isLoading && _battlegrounds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_battlegrounds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'No open matches yet. Create one and invite nearby diners.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            )
          else
            ..._battlegrounds.map(_buildCard),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> battleground) {
    final squadId =
        int.tryParse(battleground['squad_id']?.toString() ?? '') ?? 0;
    final isHost =
        battleground['is_host'] == true ||
        battleground['is_host']?.toString() == '1';
    final memberStatus = battleground['member_status']?.toString();
    final reserved =
        int.tryParse(battleground['joined_count']?.toString() ?? '') ?? 0;
    final maxPlayers =
        int.tryParse(battleground['max_players']?.toString() ?? '') ?? 10;
    final duration =
        (int.tryParse(battleground['duration_seconds']?.toString() ?? '') ??
            60) ~/
        60;
    final isJoining = _joiningSquads.contains(squadId);

    String actionLabel;
    VoidCallback? action;
    if (isHost || memberStatus == 'Joined') {
      actionLabel = isHost ? 'Manage lobby' : 'Open lobby';
      action = () => _openLobby(squadId, isHost);
    } else if (memberStatus == 'JoinRequested') {
      actionLabel = 'Request sent';
    } else if (memberStatus == 'Invited') {
      actionLabel = 'Invited';
    } else if (reserved >= maxPlayers) {
      actionLabel = 'Full';
    } else {
      actionLabel = 'Request to join';
      action = () => _requestToJoin(squadId);
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0CC)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFE0CC),
            child: Icon(Icons.sports_esports_rounded, color: Colors.deepOrange),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${battleground['host_name'] ?? 'Diner'} • Table ${battleground['table_id']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$duration min • $reserved/$maxPlayers spots reserved',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: isJoining ? null : action,
            child: isJoining
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(actionLabel, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
