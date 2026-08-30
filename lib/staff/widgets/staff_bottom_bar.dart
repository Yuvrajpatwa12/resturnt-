import 'package:flutter/material.dart';

class StaffBottomBar extends StatelessWidget {
  const StaffBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundImage: NetworkImage('https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&auto=format&fit=crop&q=60'),
          ),
          const SizedBox(width: 10),
          const Text(
            "Catherine",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
          const Spacer(),
          Text(
            "07 June, Wednesday 19:41",
            style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
