import 'package:flutter/material.dart';

class PrepTimerModal extends StatelessWidget {
  final Function(int) onSelected;

  const PrepTimerModal({
    super.key,
    required this.onSelected,
  });

  static void show(BuildContext context, Function(int) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PrepTimerModal(onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Set Preparation Time", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text("How long will this order take to be ready?", style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeChip(context, 10),
              _buildTimeChip(context, 15),
              _buildTimeChip(context, 20),
              _buildTimeChip(context, 30),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onSelected(15);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("START PREPARATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(BuildContext context, int mins) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onSelected(mins);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFFF5C00).withValues(alpha: 0.3)),
        ),
        child: Text("${mins}M", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5C00))),
      ),
    );
  }
}
