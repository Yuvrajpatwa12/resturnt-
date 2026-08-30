import 'package:flutter/material.dart';
import '../admin_theme.dart';

class AdminPlaceholderScreen extends StatelessWidget {
  final String title;
  const AdminPlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AdminTheme.royalBlue.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.construction_rounded, color: AdminTheme.royalBlue, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy),
          ),
          const SizedBox(height: 8),
          const Text(
            "This module is currently under development.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text("VIEW DOCUMENTATION"),
          ),
        ],
      ),
    );
  }
}
