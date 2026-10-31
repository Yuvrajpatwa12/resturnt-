import 'package:flutter/material.dart';
import 'dart:async';
import '../theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  DateTime? _shiftStartedAt;
  Timer? _shiftTimer;
  Duration _shiftDuration = Duration.zero;

  @override
  void dispose() {
    _shiftTimer?.cancel();
    super.dispose();
  }

  void _toggleShift() {
    setState(() {
      if (_shiftStartedAt == null) {
        _shiftStartedAt = DateTime.now();
        _shiftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || _shiftStartedAt == null) return;
          setState(() {
            _shiftDuration = DateTime.now().difference(_shiftStartedAt!);
          });
        });
      } else {
        _shiftTimer?.cancel();
        _shiftTimer = null;
        _shiftStartedAt = null;
        _shiftDuration = Duration.zero;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Waiter Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Staff Details Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [WaiterProTheme.royalBlue, WaiterProTheme.darkNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: WaiterProTheme.royalBlue.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Yuvraj Patwa",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          "Staff ID: #WT-109",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: WaiterProTheme.emeraldGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Indoor Section",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: WaiterProTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Shift",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _shiftStartedAt == null
                            ? Icons.pause_circle_outline
                            : Icons.timer_outlined,
                        color: _shiftStartedAt == null
                            ? Colors.orange
                            : WaiterProTheme.emeraldGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _shiftStartedAt == null
                              ? "Not clocked in"
                              : "On shift • ${_formatDuration(_shiftDuration)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: WaiterProTheme.darkNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _toggleShift,
                      icon: Icon(
                        _shiftStartedAt == null ? Icons.play_arrow : Icons.stop,
                      ),
                      label: Text(
                        _shiftStartedAt == null ? "Start shift" : "End shift",
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        foregroundColor: _shiftStartedAt == null
                            ? WaiterProTheme.royalBlue
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Local preview only; shift time is not saved or sent to the server.",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Shift Performance",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricCard(
                  "Sales Generated",
                  "—",
                  Icons.trending_up,
                  WaiterProTheme.royalBlue,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  "Tips Earned",
                  "—",
                  Icons.account_balance_wallet,
                  WaiterProTheme.emeraldGreen,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Performance data is not connected yet.",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _buildActionTile(Icons.history, "Shift History", () {}),
            _buildActionTile(Icons.lock_reset, "Change PIN", () {}),
            _buildActionTile(Icons.help_outline, "Support", () {}),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0,
              ),
              child: const Text("LOGOUT & HANDOVER SHIFT"),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: WaiterProTheme.softShadow,
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: WaiterProTheme.darkNavy),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      contentPadding: EdgeInsets.zero,
    );
  }
}
