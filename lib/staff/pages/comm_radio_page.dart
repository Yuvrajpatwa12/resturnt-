import 'package:flutter/material.dart';

class CommRadioPage extends StatefulWidget {
  const CommRadioPage({super.key});

  @override
  State<CommRadioPage> createState() => _CommRadioPageState();
}

class _CommRadioPageState extends State<CommRadioPage> with SingleTickerProviderStateMixin {
  bool _isHolding = false;
  String _activeChannel = "Hall Hub";
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channels = ["Hall Hub", "Kitchen", "Management", "Security"];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text("Staff Radio • Live", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          _buildSignalIndicator(),
          const SizedBox(width: 15),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                bool isSel = _activeChannel == channels[index];
                return GestureDetector(
                  onTap: () => setState(() => _activeChannel = channels[index]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFFF5C00).withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: isSel ? const Color(0xFFFF5C00) : Colors.grey[200]!),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      channels[index],
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: isSel ? const Color(0xFFFF5C00) : Colors.grey
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _isHolding ? const Color(0xFFFF5C00) : Colors.grey[100],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isHolding ? Icons.radio : Icons.radio_outlined, color: _isHolding ? Colors.white : Colors.grey, size: 18),
                const SizedBox(width: 10),
                Text(
                  _isHolding ? "BROADCASTING TO $_activeChannel" : "PTT: ${_activeChannel.toUpperCase()}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 10, 
                    letterSpacing: 1,
                    color: _isHolding ? Colors.white : Colors.grey
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 150,
                    child: _isHolding 
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(15, (index) {
                            return AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                final h = (index % 3 + 1) * 20 * _waveController.value + 20;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: 4,
                                  height: h.clamp(10, 80),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5C00),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              },
                            );
                          }),
                        )
                      : Icon(Icons.graphic_eq, size: 80, color: Colors.grey[200]),
                  ),

                  const SizedBox(height: 40),

                  GestureDetector(
                    onTapDown: (_) => setState(() => _isHolding = true),
                    onTapUp: (_) => setState(() => _isHolding = false),
                    onTapCancel: () => setState(() => _isHolding = false),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: _isHolding ? const Color(0xFFFF5C00) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5C00).withValues(alpha: _isHolding ? 0.4 : 0.1),
                            blurRadius: 30,
                            spreadRadius: _isHolding ? 10 : 2,
                          )
                        ],
                        border: Border.all(color: const Color(0xFFFF5C00), width: 10),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mic, size: 50, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              _isHolding ? "SAY NOW" : "HOLD",
                              style: TextStyle(
                                color: _isHolding ? Colors.white : const Color(0xFFFF5C00),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "STAFF ON $_activeChannel",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey),
                    ),
                    const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 20),
                _buildStaffItem("Head Waiter (Me)", "Broadcasting", true),
                _buildStaffItem("Server Noah", "Idle", false),
                _buildStaffItem("Server Sarah", "Idle", false),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalIndicator() {
    return Row(
      children: [
        const Icon(Icons.signal_cellular_alt, size: 16, color: Colors.green),
        const SizedBox(width: 8),
        Text("98%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(width: 4),
        const Icon(Icons.battery_4_bar_rounded, size: 16, color: Colors.green),
      ],
    );
  }

  Widget _buildStaffItem(String name, String status, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4,
            backgroundColor: isActive ? const Color(0xFFFF5C00) : Colors.green,
          ),
          const SizedBox(width: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          const Spacer(),
          Text(status, style: TextStyle(fontSize: 11, color: isActive ? const Color(0xFFFF5C00) : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
