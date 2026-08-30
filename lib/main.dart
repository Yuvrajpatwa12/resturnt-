import 'package:chiyabreak/super_admin/super_admin_dashboard.dart';
import 'package:flutter/material.dart';
import 'waiter_pro/theme.dart';
import 'homepage.dart';
import 'cart_manager.dart';
import 'services/tenant_service.dart';
import 'services/suspension_screen.dart';
import 'super_admin_module/master_hub.dart';

import 'services/dev_launcher.dart';

import 'services/staff_gateway.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'dart:html' as html; // Import for SessionStorage access

void main() {
  // 1. Remove the '#' from URLs (e.g. startupsgo.tech/#/ -> startupsgo.tech/)
  usePathUrlStrategy();
  
  WidgetsFlutterBinding.ensureInitialized();
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

      // 1. ROBUST TABLE DETECTION: Check Query Params AND Fragment
      String? tableParam = Uri.base.queryParameters['table'];
      
      // Fallback: Check if it's in the fragment (e.g. /#/path?table=1)
      if (tableParam == null && Uri.base.fragment.contains('table=')) {
        final fragUri = Uri.parse(Uri.base.fragment.replaceFirst('/', ''));
        tableParam = fragUri.queryParameters['table'];
      }

      // 2. RESCUE: Check Session Storage (Set by index.html JS Guard)
      if (tableParam == null) {
        tableParam = html.window.sessionStorage['rescue_table_id'];
      }

      if (tableParam != null) {
        final int? tId = int.tryParse(tableParam);
        if (tId != null) {
          ShopManager.instance.selectedTableId.value = tId;
          ShopManager.instance.isQrLaunch.value = true;
          debugPrint("QR SYSTEM: Table $tId recovered successfully.");
        }
      }

      await TenantService().initialize(domain);
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
    
    // SMART ROUTING: Use the locked flag instead of re-reading URL
    bool isQRUser = ShopManager.instance.isQrLaunch.value;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: (tenant != null && !isBypass) ? tenant.name : "ChiyaBreak SaaS (Local)",
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: themeColor,
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor),
      ),
      // If QR detected, open Customer App. If not, show Portal (Developer Mode)
      home: isQRUser ? const HomePage() : const DevLauncherScreen(),
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
