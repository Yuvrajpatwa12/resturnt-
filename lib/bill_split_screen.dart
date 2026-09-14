import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class BillSplitScreen extends StatefulWidget {
  const BillSplitScreen({super.key});

  @override
  State<BillSplitScreen> createState() => _BillSplitScreenState();
}

class _BillSplitScreenState extends State<BillSplitScreen> {
  final TextEditingController _billController = TextEditingController();
  final List<TextEditingController> _friendControllers = [
    TextEditingController(text: "Me"),
    TextEditingController(),
  ];
  
  int _priorityIndex = 0; // Default priority to first person (usually 'Me')

  @override
  void dispose() {
    _billController.dispose();
    for (var controller in _friendControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addFriend() {
    setState(() {
      _friendControllers.add(TextEditingController());
    });
  }

  void _removeFriend(int index) {
    if (_friendControllers.length > 1) {
      setState(() {
        _friendControllers.removeAt(index);
        if (_priorityIndex >= _friendControllers.length) {
          _priorityIndex = 0;
        }
      });
    }
  }

  Map<String, double> _calculateSplit() {
    final double total = double.tryParse(_billController.text) ?? 0.0;
    final int count = _friendControllers.length;
    
    if (total <= 0 || count == 0) return {};

    // 1. Calculate base equal share (rounded down to 2 decimals to prevent overcharging)
    // We use .floor() logic to ensure we don't exceed the total, then handle the penny gap.
    double equalShare = (total / count * 100).floorToDouble() / 100.0;
    
    // 2. Calculate the total of all equal shares
    double totalEqualShares = equalShare * count;
    
    // 3. The remainder (the extra pennies or rupees)
    double remainder = double.parse((total - totalEqualShares).toStringAsFixed(2));

    Map<String, double> result = {};
    for (int i = 0; i < count; i++) {
      String name = _friendControllers[i].text.trim();
      if (name.isEmpty) name = "Friend ${i + 1}";
      
      double finalShare = equalShare;
      if (i == _priorityIndex) {
        finalShare += remainder;
      }
      
      result[name] = double.parse(finalShare.toStringAsFixed(2));
    }

    return result;
  }

  void _shareOnWhatsApp() {
    final splits = _calculateSplit();
    if (splits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid bill amount first!")),
      );
      return;
    }

    final total = _billController.text;
    String message = "🍔 *Chiyala Group Bill Split* 🥤\n\n";
    message += "Total Bill: *Rs. $total*\n";
    message += "----------------------------\n";
    
    splits.forEach((name, amount) {
      bool isPriority = name == _friendControllers[_priorityIndex].text || 
                        (name == "Me" && _priorityIndex == 0);
      String marker = isPriority ? "👑 " : "👤 ";
      message += "$marker$name: *Rs. $amount*\n";
    });
    
    message += "----------------------------\n\n";
    message += "Guys, please clear your dues via *eSewa* or *Khalti* to keep our group leader happy! 😄🙏\n";
    message += "No one likes the 'where is my money' talk, so let's keep it smooth! ✨";

    Share.share(message);
  }

  void _copyToClipboard() {
    final splits = _calculateSplit();
    if (splits.isEmpty) return;

    final total = _billController.text;
    String message = "🍔 *Chiyala Group Bill Split* 🥤\n";
    message += "Total Bill: Rs. $total\n";
    splits.forEach((name, amount) => message += "👤 $name: Rs. $amount\n");
    
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bill summary copied to clipboard!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "Group Bill Splitter",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOTAL BILL CARD ---
                  _buildSectionHeader("BILL DETAILS"),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Total Bill Amount",
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _billController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00)),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          decoration: const InputDecoration(
                            hintText: "0.00",
                            prefixText: "Rs. ",
                            prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- FRIENDS LIST ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader("WHO'S PAYING?"),
                      TextButton.icon(
                        onPressed: _addFriend,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text("ADD FRIEND", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5C00)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _friendControllers.length,
                    itemBuilder: (context, index) {
                      return _buildFriendItem(index);
                    },
                  ),

                  const SizedBox(height: 24),
                  
                  // --- SUMMARY INFO ---
                  if (_billController.text.isNotEmpty)
                    _buildSummaryCard(),

                  const SizedBox(height: 100), // Spacing for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomAction(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildFriendItem(int index) {
    bool isPriority = _priorityIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPriority ? const Color(0xFFFF5C00).withValues(alpha: 0.3) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Priority Selector
          GestureDetector(
            onTap: () => setState(() => _priorityIndex = index),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPriority ? const Color(0xFFFF5C00) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPriority ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isPriority ? Colors.white : Colors.grey,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name Input
          Expanded(
            child: TextField(
              controller: _friendControllers[index],
              decoration: InputDecoration(
                hintText: "Enter friend's name",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Remove Button
          if (_friendControllers.length > 1)
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red[300], size: 20),
              onPressed: () => _removeFriend(index),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final splits = _calculateSplit();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.green, size: 20),
              const SizedBox(width: 12),
              const Text(
                "SMART SPLIT PREVIEW",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.green, letterSpacing: 0.5),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.green),
          ...splits.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text("Rs. ${e.value}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87)),
              ],
            ),
          )).toList(),
          const SizedBox(height: 12),
          Text(
            "* The remainder has been adjusted for ${_friendControllers[_priorityIndex].text.isEmpty ? 'Friend ${_priorityIndex + 1}' : _friendControllers[_priorityIndex].text}.",
            style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.green),
          )
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareOnWhatsApp,
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              label: const Text(
                "SHARE ON WHATSAPP",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy_rounded, color: Colors.grey, size: 18),
              label: const Text("COPY SUMMARY", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
