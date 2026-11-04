import 'package:flutter/material.dart';
import 'dart:async';
import 'services/tenant_service.dart';
import 'cart_manager.dart';
import 'homepage.dart';
import 'super_admin_module/master_hub.dart';
import 'services/staff_gateway.dart';
import 'package:web/web.dart' as web;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _topController;
  late AnimationController _bottomController;
  late Animation<Offset> _topAnimation;
  late Animation<Offset> _bottomAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup Animations
    _topController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _bottomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _topAnimation = Tween<Offset>(begin: const Offset(0, -2), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _topController, curve: Curves.easeOutBack),
        );

    _bottomAnimation =
        Tween<Offset>(begin: const Offset(0, 2), end: Offset.zero).animate(
          CurvedAnimation(parent: _bottomController, curve: Curves.easeOutBack),
        );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _topController,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    // 2. Start Animations
    _topController.forward();
    _bottomController.forward();

    // 3. Navigation Timer (4 seconds)
    Timer(const Duration(seconds: 4), () {
      _navigateToNext();
    });
  }

  void _navigateToNext() {
    if (!mounted) return;

    String path = '';
    try {
      // First try to get the original path from session storage (captured before URL strategy)
      final storedPath = web.window.sessionStorage.getItem('original_path');
      if (storedPath != null && storedPath.isNotEmpty) {
        path = storedPath.toLowerCase();
        debugPrint("Using stored original path: $path");
      } else {
        // Fallback to current location
        final loc = web.window.location;
        path = (loc.pathname + loc.hash).toLowerCase();
        debugPrint("Using current location path: $path");
      }
    } catch (_) {
      path = (Uri.base.path + Uri.base.fragment).toLowerCase();
      debugPrint("Using Uri.base path: $path");
    }

    // Role-based URLs take absolute precedence over cached QR table locks
    Widget? nextScreen;
    if (path.contains('/superadmin') || path.contains('/super-admin')) {
      nextScreen = const SuperAdminMasterHub();
    } else if (path.contains('/admin') || path.contains('/restaurant-admin')) {
      nextScreen = const StaffGateway(initialRoleHint: "Admin");
    } else if (path.contains('/waiter')) {
      nextScreen = const StaffGateway(initialRoleHint: "Waiter");
    } else if (path.contains('/kitchen')) {
      nextScreen = const StaffGateway(initialRoleHint: "Kitchen");
    }

    if (nextScreen != null) {
      try {
        // Explicitly preserve and synchronize browser address bar URL path
        web.window.history.replaceState(null, '', path);
      } catch (_) {}

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen!,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
      return;
    }

    bool isQRUser = ShopManager.instance.isQrLaunch.value;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            isQRUser ? const HomePage() : const HomePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _topController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF001F3F),
              Color(0xFF000000),
            ], // Premium Midnight Gradient
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative Glow
            Positioned(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.15),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),

            ValueListenableBuilder<Tenant?>(
              valueListenable: TenantService().currentTenant,
              builder: (context, tenant, _) {
                String name = tenant?.name ?? "CHIYABREAK";
                List<String> parts = name.split(" ");
                String firstPart = parts[0];
                String lastPart = parts.length > 1
                    ? parts.sublist(1).join(" ")
                    : "";

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SlideTransition(
                      position: _topAnimation,
                      child: FadeTransition(
                        opacity: _opacityAnimation,
                        child: Text(
                          firstPart.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (lastPart.isNotEmpty)
                      SlideTransition(
                        position: _bottomAnimation,
                        child: FadeTransition(
                          opacity: _opacityAnimation,
                          child: Text(
                            lastPart.toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).primaryColor, // Premium Brand Color
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 12,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                    CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                      strokeWidth: 2,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
