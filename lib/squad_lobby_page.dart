import 'package:flutter/material.dart';
import 'dart:async';
import 'services/api_service.dart';
import 'services/tenant_service.dart';
import 'cart_manager.dart';
import 'tap_war_page.dart';
import 'nearby_page.dart';

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
  bool _isFetchingStatus = false;
  Map<String, dynamic>? _squadData;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _joinRequests = [];
  Timer? _pollTimer;
  bool _startingGame = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    // Poll every 3 seconds as required by specification
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchStatus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    if (_isFetchingStatus) return;
    _isFetchingStatus = true;
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      _isFetchingStatus = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Restaurant information is not available. Try again.';
        });
      }
      return;
    }
    final myId = ShopManager.instance.currentUserId;

    try {
      final res = await ApiService.getSquadStatus(
        tenantId: tenant.id,
        squadId: widget.squadId,
        userId: myId,
      );
      if (!mounted) return;

      if (res == null || res['status'] != 'success' || res['squad'] == null) {
        setState(() {
          _isLoading = false;
          _loadError =
              res?['message']?.toString() ??
              'Could not load the Battleground lobby. Check your connection and retry.';
        });
        return;
      }

      final squad = Map<String, dynamic>.from(res['squad'] as Map);
      final members = List<Map<String, dynamic>>.from(
        res['members'] ?? const [],
      );

      setState(() {
        _squadData = squad;
        _members = members;
        _isLoading = false;
        _loadError = null;
      });

      if (widget.isHost && squad['game_type'] == 'battleground') {
        final requests = await ApiService.getBattlegroundJoinRequests(
          tenantId: tenant.id,
          squadId: widget.squadId,
        );
        if (mounted && requests != null) {
          setState(() => _joinRequests = requests);
        }
      }

      final status = squad['status']?.toString().toLowerCase();
      if (status == 'inprogress' || status == 'ready') {
        _pollTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TapWarMultiplayerPage(
              squadId: widget.squadId,
              startAt: squad['start_at'],
              isBattleground: squad['game_type'] == 'battleground',
              durationSeconds:
                  int.tryParse(squad['duration_seconds']?.toString() ?? '') ??
                  30,
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Could not load the Battleground lobby. Please retry.';
        });
      }
      debugPrint('Squad lobby status error: $e');
    } finally {
      _isFetchingStatus = false;
    }
  }

  Future<void> _respondToJoinRequest(String requesterId, bool accept) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final response = await ApiService.respondToBattlegroundJoin(
      tenantId: tenant.id,
      squadId: widget.squadId,
      requesterId: requesterId,
      accept: accept,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response?['message']?.toString() ??
              'Could not update the join request.',
        ),
      ),
    );
    if (response?['status'] == 'success') {
      _fetchStatus();
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

  Future<void> _inviteNearby() async {
    final activeMemberCount =
        _members
            .where((m) => m['status'] == 'Joined' || m['status'] == 'Invited')
            .length +
        _joinRequests.length;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NearbyPage(
          battlegroundSquadId: widget.squadId,
          battlegroundMemberCount: activeMemberCount,
          battlegroundMaxPlayers: int.tryParse(
            _squadData?['max_players']?.toString() ?? '',
          ),
        ),
      ),
    );
    if (mounted) {
      _fetchStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final joinedCount = _members.where((m) => m['status'] == 'Joined').length;
    final isBattleground = _squadData?['game_type'] == 'battleground';
    final maxPlayers =
        int.tryParse(_squadData?['max_players']?.toString() ?? '') ?? 4;
    final activeMemberCount =
        _members
            .where((m) => m['status'] == 'Joined' || m['status'] == 'Invited')
            .length +
        _joinRequests.length;
    final minimumPlayers = isBattleground ? 3 : 2;
    final bool canStart = widget.isHost && joinedCount >= minimumPlayers;
    final isForming = _squadData?['status'] == 'Forming';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          "Tap War Squad Lobby",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
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
          : _squadData == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loadError ?? 'Could not load the Battleground lobby.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _loadError = null;
                        });
                        _fetchStatus();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.sports_esports_rounded,
                          size: 48,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Squad Battle Arena",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Squad ID: #${widget.squadId} • Table #${_squadData?['table_id'] ?? '-'}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        if (isBattleground) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${(int.tryParse(_squadData?['duration_seconds']?.toString() ?? '') ?? 60) ~/ 60} minute Battleground',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (widget.isHost &&
                      isBattleground &&
                      _joinRequests.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join requests (${_joinRequests.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._joinRequests.map((request) {
                            final requesterId =
                                request['user_id']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      request['user_name']?.toString() ??
                                          'Nearby diner',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Decline',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _respondToJoinRequest(
                                      requesterId,
                                      false,
                                    ),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Accept',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _respondToJoinRequest(
                                      requesterId,
                                      true,
                                    ),
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Squad Members",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$activeMemberCount / $maxPlayers spots reserved • $joinedCount joined",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
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
                        final isHostMember =
                            m['user_id']?.toString().toLowerCase() ==
                            _squadData?['created_by_user_id']
                                ?.toString()
                                .toLowerCase();
                        final memberSource = m['member_source']?.toString();
                        Color statusColor = Colors.orange;
                        if (status == 'Joined') {
                          statusColor = Colors.green;
                        }
                        if (status == 'Declined' || status == 'Left') {
                          statusColor = Colors.red;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  m['user_name']?[0]?.toUpperCase() ?? 'U',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['user_name'] ?? 'Diner',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isHostMember
                                          ? 'Squad Host'
                                          : memberSource == 'table'
                                          ? 'Auto-added at your table'
                                          : 'Nearby member',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.isHost && isBattleground && isForming)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: activeMemberCount >= maxPlayers
                            ? null
                            : _inviteNearby,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(
                          activeMemberCount >= maxPlayers
                              ? 'Battleground full'
                              : 'Invite nearby diners',
                        ),
                      ),
                    ),
                  if (widget.isHost && isBattleground && isForming)
                    const SizedBox(height: 10),
                  if (widget.isHost)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (!canStart || _startingGame)
                            ? null
                            : _startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _startingGame
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                joinedCount < minimumPlayers
                                    ? "Waiting for players (Need ≥$minimumPlayers)..."
                                    : isBattleground
                                    ? "START BATTLEGROUND 🚀"
                                    : "START SQUAD BATTLE 🚀",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    )
                  else
                    const Center(
                      child: Text(
                        "Waiting for host to start the battle...",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
