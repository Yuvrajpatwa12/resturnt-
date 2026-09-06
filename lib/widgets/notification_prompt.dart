import 'package:flutter/material.dart';
import '../cart_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrompt extends StatelessWidget {
  const NotificationPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Prevent tap from bubbling up to dismiss background
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: Colors.white,
            elevation: 20,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      size: 40,
                      color: Color(0xFFFF5C00),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Enable Notifications",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Get real-time alerts when friends wave at you or your order status changes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            debugPrint("NOTIF PROMPT: Dismissed");
                            ShopManager.instance.showNotificationPrompt.value = false;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('notif_prompt_dismissed', true);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            "Not Now",
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            debugPrint("NOTIF PROMPT: Requesting Permission...");
                            final bool success = await ShopManager.instance.setupPushNotifications();
                            debugPrint("NOTIF PROMPT: Permission Result: $success");
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5C00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Allow",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
