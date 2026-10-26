import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cart_manager.dart';
import '../services/notification_sound_stub.dart'
    if (dart.library.js_interop) '../services/notification_sound_web.dart'
    as notification_sound;
import '../notifications_page.dart';
import '../user_profile_view_page.dart';
import '../my_orders_page.dart';
import '../rewards_page.dart';
import '../nearby_page.dart';

class GlobalNotificationBannerOverlay extends StatefulWidget {
  const GlobalNotificationBannerOverlay({super.key});

  @override
  State<GlobalNotificationBannerOverlay> createState() => _GlobalNotificationBannerOverlayState();
}

class _GlobalNotificationBannerOverlayState extends State<GlobalNotificationBannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    ShopManager.instance.latestIncomingPush.addListener(_onNewPush);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    ShopManager.instance.latestIncomingPush.removeListener(_onNewPush);
    super.dispose();
  }

  void _onNewPush() {
    final push = ShopManager.instance.latestIncomingPush.value;
    if (push != null) {
      notification_sound.playNotificationSound('notification');
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}

      _animController.forward(from: 0.0);

      _autoDismissTimer?.cancel();
      _autoDismissTimer = Timer(const Duration(seconds: 5), () {
        _dismissBanner();
      });
    } else {
      _animController.reverse();
    }
  }

  void _dismissBanner() async {
    await _animController.reverse();
    if (mounted) {
      ShopManager.instance.latestIncomingPush.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>?>(
      valueListenable: ShopManager.instance.latestIncomingPush,
      builder: (context, push, child) {
        if (push == null) return const SizedBox.shrink();

        final title = push['title'] ?? 'New Notification';
        final body = push['body'] ?? '';
        final senderId = push['sender_id'];

        // Determine icon & color based on real notification context
        IconData iconData = Icons.notifications_active_rounded;
        Color accentColor = const Color(0xFFFF5C00);

        if (title.contains('Wave') || body.contains('waved')) {
          iconData = Icons.waving_hand_rounded;
          accentColor = const Color(0xFFF59E0B); // Warm Gold
        } else if (title.contains('Order') || body.contains('order')) {
          iconData = Icons.restaurant_menu_rounded;
          accentColor = const Color(0xFFFF5C00); // Brand Orange
        } else if (title.contains('Follow') || body.contains('followed') || title.contains('Friend')) {
          iconData = Icons.person_add_rounded;
          accentColor = const Color(0xFF6366F1); // Royal Indigo
        } else if (title.contains('Offer') || title.contains('Points') || body.contains('earned') || body.contains('off')) {
          iconData = Icons.local_offer_rounded;
          accentColor = const Color(0xFF10B981); // Emerald Green
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                elevation: 10,
                shadowColor: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _dismissBanner();
                    
                    Widget pageToOpen = const NotificationsPage();
                    if (title.contains('Wave') || body.contains('waved')) {
                      if (senderId != null && senderId.isNotEmpty) {
                        pageToOpen = UserProfileViewPage(userId: senderId);
                      } else {
                        pageToOpen = const NearbyPage();
                      }
                    } else if (title.contains('Follow') || body.contains('followed')) {
                      if (senderId != null && senderId.isNotEmpty) {
                        pageToOpen = UserProfileViewPage(userId: senderId);
                      }
                    } else if (title.contains('Order') || body.contains('order')) {
                      pageToOpen = const MyOrdersPage();
                    } else if (title.contains('Offer') || title.contains('Points')) {
                      pageToOpen = const RewardsPage();
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => pageToOpen),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        letterSpacing: -0.2,
                                        decoration: TextDecoration.none,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "NOW",
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  body,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                    height: 1.3,
                                    decoration: TextDecoration.none,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _dismissBanner,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.grey[500],
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
