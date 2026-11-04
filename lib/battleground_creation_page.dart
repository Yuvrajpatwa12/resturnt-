import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/tenant_service.dart';
import 'squad_lobby_page.dart';
import 'widgets/battleground_browser.dart';

class BattlegroundCreationPage extends StatefulWidget {
  const BattlegroundCreationPage({super.key});

  @override
  State<BattlegroundCreationPage> createState() =>
      _BattlegroundCreationPageState();
}

class _BattlegroundCreationPageState extends State<BattlegroundCreationPage> {
  int _durationSeconds = 60;
  bool _isCreating = false;

  Future<void> _createBattleground() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || _isCreating) return;

    setState(() => _isCreating = true);
    final response = await ApiService.createBattleground(
      tenantId: tenant.id,
      durationSeconds: _durationSeconds,
    );
    if (!mounted) return;
    if (response != null && response['status'] == 'success') {
      final squadId = int.tryParse(response['squad_id']?.toString() ?? '');
      if (squadId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SquadLobbyPage(squadId: squadId, isHost: true),
          ),
        );
        return;
      }
    }

    setState(() => _isCreating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response?['message']?.toString() ??
              'Could not create Battleground. Sign in and try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Create Battleground',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready for a table challenge? 🎮',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Everyone at your table will be added automatically. '
                          'You can invite nearby diners in the lobby. Tie-breaks use '
                          'local device clocks without clock sync; small drift is '
                          'accepted for casual play, not ranked matches.',
                          style: TextStyle(color: Colors.black54, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Choose match length',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 60, label: Text('1 min')),
                      ButtonSegment(value: 180, label: Text('3 min')),
                      ButtonSegment(value: 300, label: Text('5 min')),
                    ],
                    selected: {_durationSeconds},
                    onSelectionChanged: _isCreating
                        ? null
                        : (selection) => setState(
                            () => _durationSeconds = selection.first,
                          ),
                  ),
                  const SizedBox(height: 24),
                  const BattlegroundBrowser(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createBattleground,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'CREATE BATTLEGROUND',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
