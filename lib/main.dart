import 'package:chiyabreak/super_admin/super_admin_dashboard.dart';
import 'package:flutter/material.dart';
import 'waiter_pro/theme.dart';
import 'homepage.dart';
import 'cart_manager.dart';
import 'services/tenant_service.dart';
import 'services/suspension_screen.dart';
import 'super_admin_module/master_hub.dart';

import 'services/staff_gateway.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:web/web.dart' as web; // Import for SessionStorage access
import 'splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Remove the '#' from URLs (e.g. startupsgo.tech/#/ -> startupsgo.tech/)
  usePathUrlStrategy();
  
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("FIREBASE INIT FAILED (Probably missing config): $e");
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
      
      // Fallback: Check if it's in the fragment (e.g. /#/path?table=1)
      if (tableParam == null && Uri.base.fragment.contains('table=')) {
        final fragUri = Uri.parse(Uri.base.fragment.replaceFirst('/', ''));
        tableParam = fragUri.queryParameters['table'];
      }

      // 2. RESCUE: Check Session Storage
      tableParam ??= web.window.sessionStorage.getItem('rescue_table_id');

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

      await TenantService().initialize(domain);
      await ShopManager.instance.fetchLoyaltySettings();
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
                  child: Text("CONNECTION ERROR: $_errorMessage\n\nCheck your Hostinger API URL and DB config.", style: const TextStyle(color: Colors.red)),
                ),
              ),
            ),
          );
        }

        return ValueListenableBuilder<Tenant?>(
          valueListenable: TenantService().currentTenant,
          builder: (context, tenant, child) {
            // BYPASS FOR LOCALHOST TESTING:
            // Agar aap PC par hain aur database set nahi hai, toh seedha Dashboard dikhao
            if (Uri.base.host == "localhost" && tenant == null) {
               return _buildMainApp(null, isBypass: true);
            }

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

            return _buildMainApp(tenant);
          },
        );
      },
    );
  }

  Widget _buildMainApp(Tenant? tenant, {bool isBypass = false}) {
    final themeColor = (tenant != null && !isBypass) 
        ? _parseColor(tenant.color) 
        : const Color(0xFFFF5C00);
    


    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: (tenant != null && !isBypass) ? tenant.name : "ChiyaBreak SaaS (Local)",
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: themeColor,
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor),
      ),
      // Set SplashScreen as the initial entry point
      home: const SplashScreen(),
      routes: {
        '/customer': (context) => const HomePage(),
        '/super-admin': (context) => const SuperAdminMasterHub(),
        '/restaurant-admin': (context) => const StaffGateway(),
        '/dashboard': (context) => const SuperAdminDashboard(),
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
