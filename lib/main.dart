import 'package:flutter/material.dart';
import 'waiter_pro/theme.dart';
import 'cart_manager.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';
import 'services/suspension_screen.dart';
import 'services/language_service.dart';
import 'services/currency_service.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:web/web.dart' as web; // Import for SessionStorage access
import 'splash_screen.dart';
import 'widgets/global_notification_overlay.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'dart:js' as js; // Add for JavaScript Handshake

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Capture the original path BEFORE any URL strategy changes
  String originalPath = '';
  try {
    final loc = web.window.location;
    originalPath = loc.pathname + loc.hash;
    debugPrint("ORIGINAL PATH CAPTURED: $originalPath");
    // Store in session storage to survive URL strategy changes
    web.window.sessionStorage.setItem('original_path', originalPath);
  } catch (e) {
    debugPrint("Failed to capture original path: $e");
  }

  // 2. Notify JS that Dart has started
  try {
    js.context.callMethod('onFlutterAppStarted');
  } catch (e) {
    debugPrint("Handshake failed: $e");
  }

  // 3. Remove the '#' from URLs
  usePathUrlStrategy();

  // 3. Initialize Services
  await LanguageService().initialize();
  await CurrencyService().initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("FIREBASE INIT FAILED: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      String domain = Uri.base.host;
      if (domain == "127.0.0.1") domain = "localhost";

      // Remove 'www.' for consistent matching
      if (domain.startsWith('www.')) domain = domain.substring(4);

      debugPrint("INIT: Detecting environment for domain: $domain");

      // 1. FAST TABLE DETECTION
      String? tableParam = Uri.base.queryParameters['table'];
      String? tenantParam = Uri.base.queryParameters['tenant_id'];

      // Fallback: Check if it's in the fragment (e.g. /#/path?table=1)
      if ((tableParam == null || tenantParam == null) &&
          Uri.base.fragment.contains('table=')) {
        final fragUri = Uri.parse(Uri.base.fragment.replaceFirst('/', ''));
        tableParam ??= fragUri.queryParameters['table'];
        tenantParam ??= fragUri.queryParameters['tenant_id'];
      }

      // 2. RESCUE: Check Session Storage
      if (tenantParam == null || tenantParam.trim().isEmpty) {
        tableParam ??= web.window.sessionStorage.getItem('rescue_table_id');
      } else {
        web.window.sessionStorage.removeItem('rescue_table_id');
      }

      if (tableParam != null) {
        final int? tId = int.tryParse(tableParam);
        if (tId != null) {
          ShopManager.instance.selectedTableId.value = tId;
          ShopManager.instance.isQrLaunch.value = true;
          // LOCK IT IN SESSION STORAGE
          web.window.sessionStorage.setItem('rescue_table_id', tId.toString());
          debugPrint("QR SYSTEM: Table $tId locked in session storage.");
        }
      }

      await TenantService().initialize(domain, tenantId: tenantParam);
      await ShopManager.instance.fetchLoyaltySettings();
      await ShopManager.instance.refreshMusicStatus();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TenantService().isLoading,
      builder: (context, isLoading, child) {
        if (isLoading && _errorMessage == null) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
              ),
            ),
          );
        }

        // Show real error if connection failed
        if (_errorMessage != null) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "CONNECTION ERROR: $_errorMessage\n\nCheck your Hostinger API URL and DB config.",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          );
        }

        return ValueListenableBuilder<Tenant?>(
          valueListenable: TenantService().currentTenant,
          builder: (context, tenant, child) {
            if (tenant == null || !tenant.isActive) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: WaiterProTheme.lightTheme,
                home: AccountSuspendedScreen(
                  reason: tenant == null
                      ? "Domain [${Uri.base.host}] is not registered. Please add it to the Super Admin hub."
                      : "Subscription Expired or Account Suspended.",
                ),
              );
            }

            // Build app with tenant's theme - this will rebuild when tenant changes
            final themeColor = _parseColor(tenant.color);
            final fontFamily = tenant.fontFamily ?? 'Inter';
            final borderRadius = tenant.borderRadius ?? 16.0;
            final isDarkMode = tenant.darkModeEnabled ?? false;

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: tenant.name,
              theme: ThemeData(
                useMaterial3: true,
                primaryColor: themeColor,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: themeColor,
                  brightness: isDarkMode ? Brightness.dark : Brightness.light,
                ),
                fontFamily: fontFamily,
                cardTheme: CardThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
              home: const SplashScreen(),
              onGenerateRoute: (settings) {
                // Handle browser back button properly
                return null;
              },
              builder: (context, child) {
                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                    // Handle browser back button - delegate to Navigator
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: Stack(
                    children: [
                      if (child != null) child,
                      const GlobalNotificationBannerOverlay(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFFFF5C00);
    }
  }
}
