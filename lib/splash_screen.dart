import 'package:flutter/material.dart';
import 'dart:async';
import 'services/tenant_service.dart';
import 'services/api_service.dart';
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

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) {
      return const Color(0xFFFFB800); // Warm Amber Gold
    }
    try {
      String cleanHex = hexString.replaceAll('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFFFFB800);
    }
  }

  String _getFormattedLogoUrl(String rawUrl) {
    if (rawUrl.isEmpty) return "";
    if (rawUrl.startsWith("http://") || rawUrl.startsWith("https://")) {
      return rawUrl;
    }
    String cleanPath = rawUrl.startsWith('/') ? rawUrl.substring(1) : rawUrl;
    String baseDomain = ApiService.baseUrl.replaceFirst('/saas_api', '');
    return "$baseDomain/$cleanPath";
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Tenant?>(
      valueListenable: TenantService().currentTenant,
      builder: (context, tenant, _) {
        final Color brandBgColor = _parseColor(tenant?.color);
        final String name = tenant?.name ?? "CHIYABREAK";
        final String rawLogo = tenant?.logo ?? "";
        final String logoUrl = _getFormattedLogoUrl(rawLogo);

        return Scaffold(
          backgroundColor: brandBgColor,
          body: Stack(
            children: [
              // CENTER CONTENT (Logo, Name, Loader)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 1. UPLOADED RESTAURANT LOGO (OR FALLBACK ICON)
                      SlideTransition(
                        position: _topAnimation,
                        child: FadeTransition(
                          opacity: _opacityAnimation,
                          child: Container(
                            width: 140,
                            height: 140,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: logoUrl.isNotEmpty
                                ? Image.network(
                                    logoUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.storefront_rounded,
                                      size: 64,
                                      color: Color(0xFF6B21A8),
                                    ),
                                  )
                                : const Icon(
                                    Icons.storefront_rounded,
                                    size: 64,
                                    color: Color(0xFF6B21A8),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 2. RESTAURANT NAME
                      SlideTransition(
                        position: _bottomAnimation,
                        child: FadeTransition(
                          opacity: _opacityAnimation,
                          child: Column(
                            children: [
                              Text(
                                name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF6B21A8), // Deep Rich Purple
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.white38,
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "TIME FOR A REFRESHING BREAK",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF6B21A8)
                                      .withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // 3. MINIMALIST LOADER
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: Color(0xFF6B21A8),
                          strokeWidth: 2.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // BOTTOM FOOTER: "from" above "startupsgo"
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Center(
                    child: FadeTransition(
                      opacity: _opacityAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "from",
                            style: TextStyle(
                              color: const Color(0xFF6B21A8)
                                  .withValues(alpha: 0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "startupsgo",
                            style: TextStyle(
                              color: Color(0xFF6B21A8),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
