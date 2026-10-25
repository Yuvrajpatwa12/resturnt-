import 'package:flutter/material.dart';
import '../cart_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrompt extends StatefulWidget {
  const NotificationPrompt({super.key});

  @override
  State<NotificationPrompt> createState() => _NotificationPromptState();
}

class _NotificationPromptState extends State<NotificationPrompt> {
  bool _isLoading = false;
  bool _isSuccess = false;
  bool _hasError = false;

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
                      color:
                          (_isSuccess ? Colors.green : const Color(0xFFFF5C00))
                              .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF5C00),
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            _isSuccess
                                ? Icons.check_circle_outline
                                : Icons.notifications_active_outlined,
                            size: 40,
                            color: _isSuccess
                                ? Colors.green
                                : const Color(0xFFFF5C00),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isSuccess
                        ? "Notifications Enabled!"
                        : _hasError
                        ? "Couldn't Enable Notifications"
                        : "Enable Notifications",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isSuccess
                        ? "You're all set! Push alerts are enabled for this browser."
                        : _hasError
                        ? "Check that this site is open over HTTPS, browser notifications are allowed, and try again."
                        : "Get real-time alerts when friends wave at you or your order status changes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!_isSuccess)
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    debugPrint("NOTIF PROMPT: Dismissed");
                                    ShopManager
                                            .instance
                                            .showNotificationPrompt
                                            .value =
                                        false;
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setBool(
                                      'notif_prompt_dismissed',
                                      true,
                                    );
                                  },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              "Not Now",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() => _isLoading = true);
                                    debugPrint(
                                      "NOTIF PROMPT: Requesting Permission...",
                                    );

                                    // Start 2-second loading animation
                                    await Future.delayed(
                                      const Duration(seconds: 2),
                                    );

                                    final bool success = await ShopManager
                                        .instance
                                        .setupPushNotifications();
                                    debugPrint(
                                      "NOTIF PROMPT: Permission Result: $success",
                                    );

                                    setState(() {
                                      _isLoading = false;
                                      _isSuccess = success;
                                      _hasError = !success;
                                    });

                                    if (!success) return;

                                    // Wait 1.5 seconds to show success state before closing
                                    await Future.delayed(
                                      const Duration(milliseconds: 1500),
                                    );
                                    ShopManager
                                            .instance
                                            .showNotificationPrompt
                                            .value =
                                        false;
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
                            child: Text(
                              _hasError ? "Try Again" : "Allow",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
