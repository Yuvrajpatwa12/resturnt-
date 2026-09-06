import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:chiyabreak/models.dart';
import 'package:chiyabreak/services/tenant_service.dart';
import 'package:chiyabreak/services/api_service.dart';

enum OrderStatus { pending, approved, preparing, ready }

class CartItem {
  final Product product;
  int quantity;
  String? notes;
  String? size; // Small, Medium, Large
  List<String>? extras; // Extra Shot, Syrup, etc.

  CartItem({
    required this.product, 
    this.quantity = 1, 
    this.notes, 
    this.size = "Medium",
    this.extras,
  });
}

class ShopManager {
  static final ShopManager instance = ShopManager._internal();
  factory ShopManager() => instance;
  ShopManager._internal() {
    _startGlobalTimer();
    _loadPersistedOrder();
    _startPresenceCheckIn();
    _startWavePoller();
    _startNotificationsPoller();
    _initPushListeners();
  }

  void _initPushListeners() {
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint("FCM: Received foreground message: ${message.notification?.title}");
          refreshNotifications();
        });
      }
    } catch (e) {
      debugPrint("FCM Listener Error: $e");
    }
  }

  void _startNotificationsPoller() {
    Timer.periodic(const Duration(seconds: 15), (timer) => refreshNotifications());
  }

  final ValueNotifier<int> unseenNotificationsCount = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> notificationsList = ValueNotifier<List<Map<String, dynamic>>>([]);

  Future<void> refreshNotifications() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final data = await ApiService.fetchNotifications(tenant.id, uid);
    if (data != null && data['status'] == 'success') {
      notificationsList.value = List<Map<String, dynamic>>.from(data['data'] ?? []);
      unseenNotificationsCount.value = data['unseen_count'] ?? 0;
    }
  }

  Future<void> clearNotificationBadge() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final bool success = await ApiService.markNotificationsRead(tenant.id, uid);
    if (success) {
      unseenNotificationsCount.value = 0;
    }
  }

  void _startWavePoller() {
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      final tenant = TenantService().currentTenant.value;
      final staff = TenantService().currentStaff.value;
      final uid = staff != null ? staff.id.toString() : guestId.value;

      if (tenant != null && uid.isNotEmpty) {
        final waves = await ApiService.fetchWaves(tenant.id, uid);
        if (waves != null && waves.isNotEmpty) {
          HapticFeedback.vibrate();
          debugPrint("SOCIAL: Received ${waves.length} waves!");
        }
      }
    });
  }

  void _startPresenceCheckIn() {
    Timer.periodic(const Duration(minutes: 5), (timer) => updatePresenceOnServer());
  }

  Future<void> updatePresenceOnServer() async {
    final tenant = TenantService().currentTenant.value;
    final staff = TenantService().currentStaff.value;
    final uid = currentUserId;
    final uname = staff != null ? staff.name : (customerName.value.isNotEmpty ? customerName.value : null);
    
    if (tenant != null && uid.isNotEmpty && selectedTableId.value != null) {
      await ApiService.updatePresence(
        tenantId: tenant.id,
        userId: uid,
        tableNumber: selectedTableId.value!,
        userName: uname,
      );
    }
  }

  Future<void> _loadPersistedOrder() async {
    final prefs = await SharedPreferences.getInstance();
    isOnboardingComplete.value = prefs.getBool('onboarding_complete') ?? false;

    String? savedEmail = prefs.getString('customer_email');
    if (savedEmail != null) {
      await syncCustomerIdentity(savedEmail);
    } else {
      Future.delayed(const Duration(seconds: 2), () {
         isEmailSynced.value = false; 
      });
    }

    String? gId = prefs.getString('guest_id');
    if (gId == null) {
      gId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('guest_id', gId);
    }
    guestId.value = gId;

    final savedIds = prefs.getStringList('active_order_ids');
    if (savedIds != null && savedIds.isNotEmpty) {
      activeOrderIds.value = savedIds.map((id) => int.parse(id)).toList();
      isOrderActive.value = true;
      _startStatusSync();
    }
    
    await fetchLoyaltySettings();
    await refreshUserPoints();
    await refreshSocialStats();
    checkNotificationPermission();
  }

  Future<void> _persistOrder(int id, {bool isRemove = false}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> current = prefs.getStringList('active_order_ids') ?? [];
    
    if (isRemove) {
      current.remove(id.toString());
    } else if (!current.contains(id.toString())) {
      current.add(id.toString());
    }
    
    await prefs.setStringList('active_order_ids', current);
    activeOrderIds.value = current.map((e) => int.parse(e)).toList();
  }

  void _startGlobalTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _decrementTableTimers();
    });
  }

  void _decrementTableTimers() {
    if (tableCountdownTimers.value.isEmpty) return;
    Map<int, int> current = Map.from(tableCountdownTimers.value);
    bool changed = false;
    current.forEach((id, seconds) {
      if (seconds > 0) {
        current[id] = seconds - 1;
        changed = true;
      }
    });
    if (changed) tableCountdownTimers.value = current;
  }

  void startTableTimer(int tableId, int minutes) {
    Map<int, int> timers = Map.from(tableCountdownTimers.value);
    Map<int, int> originals = Map.from(tableOriginalDurations.value);
    int seconds = minutes * 60;
    timers[tableId] = seconds;
    originals[tableId] = seconds;
    tableCountdownTimers.value = timers;
    tableOriginalDurations.value = originals;
    updateTableStatus(tableId, "Dining");
  }

  final ValueNotifier<List<CartItem>> items = ValueNotifier<List<CartItem>>([]);
  final ValueNotifier<List<CartItem>> placedOrderItems = ValueNotifier<List<CartItem>>([]);
  final ValueNotifier<int> currentTabIndex = ValueNotifier<int>(0);
  final ValueNotifier<bool> isTenantActive = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isQrLaunch = ValueNotifier<bool>(false);
  final ValueNotifier<int?> selectedTableId = ValueNotifier<int?>(null);
  final ValueNotifier<String> guestId = ValueNotifier<String>('');
  final ValueNotifier<String> customerEmail = ValueNotifier<String>('');
  final ValueNotifier<String> customerName = ValueNotifier<String>('');
  final ValueNotifier<bool> needsPin = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isEmailSynced = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isNewToShop = ValueNotifier<bool>(false);
  final ValueNotifier<String> userGender = ValueNotifier<String>('Male');
  final ValueNotifier<bool> isOnboardingComplete = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showNotificationPrompt = ValueNotifier<bool>(false);

  String get currentUserId {
    final staff = TenantService().currentStaff.value;
    if (staff != null) return staff.id.toString();
    if (customerEmail.value.isNotEmpty) return customerEmail.value;
    return guestId.value;
  }
  
  final ValueNotifier<List<int>> activeOrderIds = ValueNotifier<List<int>>([]);
  final ValueNotifier<int?> activeOrderId = ValueNotifier<int?>(null); 
  final ValueNotifier<String?> activeCategory = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isOrderActive = ValueNotifier<bool>(false);
  final ValueNotifier<OrderStatus> orderStatus = ValueNotifier<OrderStatus>(OrderStatus.pending);
  final ValueNotifier<Duration> totalGameTime = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<int> totalOrdersCount = ValueNotifier<int>(0);

  final ValueNotifier<int> followersCount = ValueNotifier<int>(852);
  final ValueNotifier<int> followingCount = ValueNotifier<int>(156);
  final ValueNotifier<int> connectionsCount = ValueNotifier<int>(100);

  Future<bool> toggleFollow(String targetId) async {
    final tenant = TenantService().currentTenant.value;
    final myId = currentUserId;

    if (tenant != null && myId.isNotEmpty && myId != targetId) {
      final res = await ApiService.toggleFollow(tenantId: tenant.id, myId: myId, targetId: targetId);
      if (res['success'] == true) {
        await refreshSocialStats();
        return true;
      }
    }
    return false;
  }

  Future<void> refreshSocialStats() async {
    final tenant = TenantService().currentTenant.value;
    final staff = TenantService().currentStaff.value;
    final myId = staff != null ? staff.id.toString() : guestId.value;

    if (tenant != null && myId.isNotEmpty) {
      final data = await ApiService.fetchSocialStats(tenant.id, myId);
      if (data != null && data['status'] == 'success') {
        followersCount.value = data['followers'] ?? 0;
        followingCount.value = data['following'] ?? 0;
        connectionsCount.value = data['connections'] ?? 0;
      }
    }
  }

  Future<void> syncCustomerIdentity(String email, {String? name}) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final res = await ApiService.syncCustomerProfile(tenantId: tenant.id, email: email, name: name);
    if (res != null && res['status'] == 'success') {
      customerEmail.value = email;
      customerName.value = res['user']?['name'] ?? 'Guest';
      needsPin.value = res['needs_pin'] == true;
      isNewToShop.value = res['is_new_to_shop'] == true;
      isEmailSynced.value = true;
      userPoints.value = res['user']?['points'] ?? 0;
      orderStampCount.value = res['user']?['order_count'] ?? 0;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_email', email);
    }
  }

  Future<bool> finalizeSecurityPin(String pin) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || customerEmail.value.isEmpty) return false;

    final bool success = await ApiService.saveCustomerPin(tenantId: tenant.id, email: customerEmail.value, pin: pin);
    if (success) {
      needsPin.value = false;
      await fetchSocialLists();
    }
    return success;
  }

  Future<bool> updateProfile({required String name, required String gender, bool isAnon = false}) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return false;
    
    final uid = currentUserId;
    if (uid.isEmpty) return false;

    final bool success = await ApiService.submitOnboarding(
      tenantId: tenant.id, 
      userId: uid, 
      name: name, 
      gender: gender,
      isAnonymous: isAnon,
    );

    if (success) {
      customerName.value = name;
      userGender.value = gender;
      isOnboardingComplete.value = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await refreshSocialStats();
      await fetchSocialLists();
      await setupPushNotifications();
    }
    return success;
  }

  Future<void> checkNotificationPermission() async {
    if (!kIsWeb) return; 

    try {
      if (Firebase.apps.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notif_prompt_dismissed') == true) {
        debugPrint("FCM: Prompt already dismissed by user.");
        return;
      }

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.getNotificationSettings();
      
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        showNotificationPrompt.value = true;
      } else if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        setupPushNotifications();
      }
    } catch (e) {
      debugPrint("FCM Permission Check Error: $e");
    }
  }

  Future<bool> setupPushNotifications() async {
    final tenant = TenantService().currentTenant.value;
    final uid = currentUserId;
    if (tenant == null || uid.isEmpty) {
      debugPrint("FCM ERROR: Tenant or User ID is missing.");
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        debugPrint("FCM ERROR: Firebase is not initialized.");
        return false;
      }

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      debugPrint("FCM: Requesting Permission...");
      
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      debugPrint("FCM: Permission status: ${settings.authorizationStatus}");
      
      final prefs = await SharedPreferences.getInstance();
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint("FCM: Getting token with VAPID key...");
        final token = await messaging.getToken(
          vapidKey: 'BGfucW_HKKPEUrswHLq1S-WGdeyHv6jTkSGvsJ_bP20OelPwEpMcsxAkhpf34iK3g-H1E8NVVY8Vo96bIyxagQg', 
        );
        
        if (token != null && token.isNotEmpty) {
          debugPrint("FCM: Token retrieved: $token");
          final bool success = await ApiService.updateFcmToken(
            tenantId: tenant.id, 
            userId: uid, 
            token: token
          );
          debugPrint("FCM: Server sync status: $success");
          showNotificationPrompt.value = false;
          await prefs.setBool('notif_prompt_dismissed', true);
          return success;
        } else {
          debugPrint("FCM ERROR: Token is null or empty.");
        }
      } else {
        debugPrint("FCM: Permission denied by user.");
        showNotificationPrompt.value = false;
        await prefs.setBool('notif_prompt_dismissed', true);
      }
    } catch (e) { 
      debugPrint("FCM SYSTEM ERROR: $e"); 
    } finally {
      showNotificationPrompt.value = false;
    }
    return false;
  }

  final ValueNotifier<List<Map<String, dynamic>>> followingList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> requestsList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> friendsList = ValueNotifier([]);

  Future<void> fetchSocialLists() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    
    final uid = currentUserId;

    final following = await ApiService.fetchSocialList(action: 'get_following', tenantId: tenant.id, userId: uid);
    final requests = await ApiService.fetchSocialList(action: 'get_requests', tenantId: tenant.id, userId: uid);
    final friends = await ApiService.fetchSocialList(action: 'get_friends', tenantId: tenant.id, userId: uid);

    if (following != null) followingList.value = List<Map<String, dynamic>>.from(following);
    if (requests != null) requestsList.value = List<Map<String, dynamic>>.from(requests);
    if (friends != null) friendsList.value = List<Map<String, dynamic>>.from(friends);

    final orderData = await ApiService.fetchUserOrders(tenant.id, uid);
    if (orderData != null) {
      totalOrdersCount.value = orderData['total_count'] ?? 0;
    }
  }

  final ValueNotifier<List<Map<String, dynamic>>> allPurchases = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<List<Map<String, dynamic>>> allSuppliers = ValueNotifier<List<Map<String, dynamic>>>([]);

  final ValueNotifier<Map<String, dynamic>?> loyaltySettings = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<int> userPoints = ValueNotifier<int>(1250);

  Future<void> fetchLoyaltySettings() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final settings = await ApiService.fetchLoyaltySettings(tenant.id);
    if (settings != null) {
      loyaltySettings.value = settings;
    }
  }

  Future<void> refreshUserPoints() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    
    final uid = currentUserId;
    if (uid.isEmpty) return;
    
    final response = await http.get(Uri.parse("${ApiService.baseUrl}/loyalty_api.php?action=get_points&user_id=$uid&tenant_id=${tenant.id}"));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        userPoints.value = data['points'] ?? 0;
        orderStampCount.value = data['order_count'] ?? 0;
      }
    }
  }

  Future<void> syncProcurementData(String tenantId) async {
    final supData = await ApiService.fetchSuppliers(tenantId);
    final purData = await ApiService.fetchPurchases(tenantId);
    if (supData != null) allSuppliers.value = List<Map<String, dynamic>>.from(supData);
    if (purData != null) allPurchases.value = List<Map<String, dynamic>>.from(purData);
  }

  final ValueNotifier<int> orderCoins = ValueNotifier<int>(50);
  final ValueNotifier<int> groupCoins = ValueNotifier<int>(200);
  final ValueNotifier<int> orderStampCount = ValueNotifier<int>(8);
  final ValueNotifier<bool> isGroupActive = ValueNotifier<bool>(false);
  final List<Map<String, dynamic>> currentGroupMembers = [];
  bool hasNewOrderCoins = false;

  final ValueNotifier<bool> isMysteryBoxOpened = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRewardClaimed = ValueNotifier<bool>(false);
  bool isConnectedToRestaurantWiFi = true;

  final ValueNotifier<Map<String, dynamic>?> activeWave = ValueNotifier<Map<String, dynamic>?>(null);

  final ValueNotifier<bool> isLocationHidden = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isWaveEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showSocialStatus = ValueNotifier<bool>(true);
  final ValueNotifier<bool> onlyMutualChat = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showTableNumber = ValueNotifier<bool>(true);
  final ValueNotifier<bool> socialVibration = ValueNotifier<bool>(true);
  final ValueNotifier<bool> autoWaveBack = ValueNotifier<bool>(false);

  void sendWave(Map<String, dynamic> friend) {
    if (!isWaveEnabled.value) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (isWaveEnabled.value) {
        activeWave.value = friend;
      }
    });
  }

  void clearWave() {
    activeWave.value = null;
  }

  final ValueNotifier<bool> isWaterRequested = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isWaiterRequested = ValueNotifier<bool>(false);
  final ValueNotifier<int> waterCooldown = ValueNotifier<int>(0);
  final ValueNotifier<int> waiterCooldown = ValueNotifier<int>(0);

  final ValueNotifier<bool> isOrderPaid = ValueNotifier<bool>(false);

  final ValueNotifier<Map<String, dynamic>> currentSong = ValueNotifier<Map<String, dynamic>>({
    'title': 'Midnight City',
    'artist': 'M83',
    'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60',
    'progress': 0.45,
    'dedication': 'For Everyone @ Arby\'s',
  });

  final ValueNotifier<List<Map<String, dynamic>>> meatStamps = ValueNotifier<List<Map<String, dynamic>>>([
    {'id': 'beef', 'name': 'Roast Beef', 'icon': Icons.kebab_dining, 'isCollected': true, 'date': 'Aug 12, 2026'},
    {'id': 'brisket', 'name': 'Smoke Brisket', 'icon': Icons.outdoor_grill_rounded, 'isCollected': true, 'date': 'Aug 15, 2026'},
    {'id': 'chicken', 'name': 'Classic Chicken', 'icon': Icons.lunch_dining, 'isCollected': false, 'date': null},
    {'id': 'turkey', 'name': 'Roast Turkey', 'icon': Icons.restaurant_rounded, 'isCollected': false, 'date': null},
    {'id': 'bacon', 'name': 'Pepper Bacon', 'icon': Icons.bakery_dining_rounded, 'isCollected': true, 'date': 'Yesterday'},
  ]);

  bool get allStampsCollected => orderStampCount.value >= 20;

  final ValueNotifier<int> vibeScore = ValueNotifier<int>(65);

  final ValueNotifier<Map<String, dynamic>?> activePoll = ValueNotifier<Map<String, dynamic>?>(null);

  final ValueNotifier<bool> isTapWarActive = ValueNotifier<bool>(false);
  final ValueNotifier<int> tapWarTimer = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> tapLeaderboard = ValueNotifier<List<Map<String, dynamic>>>([]);
  Timer? _gameTimer;

  void startTapWar() {
    isTapWarActive.value = true;
    tapWarTimer.value = 30;
    tapLeaderboard.value = [
      {'table': 'Table 12', 'score': 0, 'isUser': true},
      {'table': 'Table 4', 'score': 0, 'isUser': false},
      {'table': 'Table 8', 'score': 0, 'isUser': false},
      {'table': 'Table 21', 'score': 0, 'isUser': false},
    ];

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (tapWarTimer.value > 0) {
        tapWarTimer.value--;
        _mockOpponentTaps();
      } else {
        timer.cancel();
      }
    });
  }

  void _mockOpponentTaps() {
    List<Map<String, dynamic>> current = List.from(tapLeaderboard.value);
    for (var item in current) {
      if (!item['isUser']) {
        item['score'] += (DateTime.now().millisecond % 7) + 2;
      }
    }
    current.sort((a, b) => b['score'].compareTo(a['score']));
    tapLeaderboard.value = current;
  }

  void recordTap() {
    if (tapWarTimer.value <= 0) return;
    List<Map<String, dynamic>> current = List.from(tapLeaderboard.value);
    int userIndex = current.indexWhere((i) => i['isUser']);
    if (userIndex != -1) {
      current[userIndex]['score'] += 1;
    }
    current.sort((a, b) => b['score'].compareTo(a['score']));
    tapLeaderboard.value = current;
  }

  void endTapWar() {
    _gameTimer?.cancel();
    isTapWarActive.value = false;
    tapWarTimer.value = 0;
  }

  void updateTableName(String oldName, String newName) {
    List<Map<String, dynamic>> current = List.from(tapLeaderboard.value);
    int index = current.indexWhere((i) => i['table'] == oldName);
    if (index != -1) {
      current[index]['table'] = newName;
      tapLeaderboard.value = current;
    }
  }

  final ValueNotifier<Map<int, List<CartItem>>> tableOrders = ValueNotifier<Map<int, List<CartItem>>>({});
  final ValueNotifier<Map<int, List<CartItem>>> confirmedTableOrders = ValueNotifier<Map<int, List<CartItem>>>({});
  final ValueNotifier<Map<int, String>> tableStatuses = ValueNotifier<Map<int, String>>({});
  final ValueNotifier<Map<int, DateTime>> tableStartTimes = ValueNotifier<Map<int, DateTime>>({});
  final ValueNotifier<Map<int, int>> tableCountdownTimers = ValueNotifier<Map<int, int>>({});
  final ValueNotifier<Map<int, int>> tableOriginalDurations = ValueNotifier<Map<int, int>>({});
  final ValueNotifier<Map<int, String>> tableKitchenStages = ValueNotifier<Map<int, String>>({});
  final ValueNotifier<Map<int, bool>> tableReadyNotifications = ValueNotifier<Map<int, bool>>({});
  
  final ValueNotifier<List<Map<String, dynamic>>> staffDirectory = ValueNotifier<List<Map<String, dynamic>>>([
    {'id': 'WT-101', 'name': 'Catherine', 'role': 'Waiter', 'pin': '1111', 'shift': 'Morning', 'sales': 45200, 'tips': 1200},
    {'id': 'WT-102', 'name': 'Noah', 'role': 'Waiter', 'pin': '2222', 'shift': 'Evening', 'sales': 32100, 'tips': 850},
    {'id': 'CH-001', 'name': 'Chef Yuvraj', 'role': 'Chef', 'pin': '0000', 'shift': 'Morning', 'sales': 0, 'tips': 0},
    {'id': 'CS-001', 'name': 'Sarah', 'role': 'Cashier', 'pin': '9999', 'shift': 'Full-time', 'sales': 88400, 'tips': 0},
  ]);

  final ValueNotifier<Map<String, dynamic>> inventoryStock = ValueNotifier<Map<String, dynamic>>({});

  final ValueNotifier<List<Map<String, dynamic>>> allHistoricalBills = ValueNotifier<List<Map<String, dynamic>>>([
    {'id': '146', 'table': 'Table 7', 'date': '20/08/2026', 'timestamp': DateTime.now(), 'time': '10:35 AM', 'items': [{'name': 'Iced Americano', 'qty': 2, 'price': 'NPR 600'}, {'name': 'Croque-Monsieur', 'qty': 1, 'price': 'NPR 650'}], 'total': 'NPR 1,250', 'status': 'Active', 'server': 'Catherine'},
    {'id': '145', 'table': 'Table 5', 'date': '20/08/2026', 'timestamp': DateTime.now().subtract(const Duration(days: 1)), 'time': '10:28 AM', 'items': [{'name': 'Cold Brew', 'qty': 1, 'price': 'NPR 450'}, {'name': 'Chiya', 'qty': 1, 'price': 'NPR 449'}], 'total': 'NPR 899', 'status': 'Active', 'server': 'Noah'},
    {'id': '144', 'table': 'Table 1', 'date': '20/08/2026', 'timestamp': DateTime.now().subtract(const Duration(days: 2)), 'time': '10:15 AM', 'items': [{'name': 'Matcha Frappe', 'qty': 1, 'price': 'NPR 750'}, {'name': 'Iced Black', 'qty': 1, 'price': 'NPR 750'}], 'total': 'NPR 1,500', 'status': 'Billed', 'server': 'Sarah'},
  ]);

  final ValueNotifier<int?> activeStaffTableId = ValueNotifier<int?>(null);
  final ValueNotifier<int> waiterTabIndex = ValueNotifier<int>(0);
  final ValueNotifier<Map<int, Map<String, CartItem>>> pendingTableOrders = ValueNotifier<Map<int, Map<String, CartItem>>>({});

  void setPendingItem(int tableId, Map<String, dynamic> p, int qty) {
    Map<int, Map<String, CartItem>> allPending = Map.from(pendingTableOrders.value);
    Map<String, CartItem> tablePending = Map.from(allPending[tableId] ?? {});
    String title = p['title'];
    if (qty <= 0) {
      tablePending.remove(title);
    } else {
      Product product = Product(title: p['title'], price: p['price'], image: p['image'], tag: p['tag'] ?? "Staff", rating: p['rating'] ?? "N/A", discount: p['discount'] ?? "");
      tablePending[title] = CartItem(product: product, quantity: qty);
    }
    allPending[tableId] = tablePending;
    pendingTableOrders.value = allPending;
  }

  void clearPendingOrder(int tableId) {
    Map<int, Map<String, CartItem>> allPending = Map.from(pendingTableOrders.value);
    allPending.remove(tableId);
    pendingTableOrders.value = allPending;
  }

  final Map<String, dynamic> salesStats = {'totalSales': 'NPR 145,943', 'salesChange': '+14%', 'totalOrders': '116', 'ordersChange': '+11%', 'avgOrderValue': 'NPR 8.12K', 'avgValueChange': '-3%', 'reservations': '34', 'resChange': '-5%'};

  void initializeTables(int tablesPerFloor) {
    if (tableStatuses.value.isNotEmpty) return;
    Map<int, String> initialStatuses = {};
    for (int i = 1; i <= tablesPerFloor; i++) {
      initialStatuses[100 + i] = "Available";
    }
    for (int i = 1; i <= tablesPerFloor; i++) {
      initialStatuses[200 + i] = "Available";
    }
    tableStatuses.value = initialStatuses;
  }

  void updateTableStatus(int tableId, String status) {
    Map<int, String> current = Map.from(tableStatuses.value);
    current[tableId] = status;
    tableStatuses.value = current;
    if (status == "Dining" && !tableStartTimes.value.containsKey(tableId)) {
      Map<int, DateTime> times = Map.from(tableStartTimes.value);
      times[tableId] = DateTime.now();
      tableStartTimes.value = times;
    }
  }

  void settleTable(int tableId) {
    updateTableStatus(tableId, "Available");
    Map<int, List<CartItem>> orders = Map.from(tableOrders.value);
    orders.remove(tableId);
    tableOrders.value = orders;
    Map<int, DateTime> times = Map.from(tableStartTimes.value);
    times.remove(tableId);
    tableStartTimes.value = times;
    clearPendingOrder(tableId);
  }

  static int parseTableId(String tableIdStr) {
    final numericOnly = tableIdStr.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numericOnly) ?? 0;
  }

  void addOrderToTable(int tableId, List<CartItem> newItems) {
    Map<int, List<CartItem>> orders = Map.from(tableOrders.value);
    List<CartItem> existing = List.from(orders[tableId] ?? []);
    for (var newItem in newItems) {
      int index = existing.indexWhere((i) => i.product.title == newItem.product.title && i.notes == newItem.notes);
      if (index != -1) {
        existing[index].quantity += newItem.quantity;
      } else {
        existing.add(newItem);
      }
    }
    orders[tableId] = existing;
    tableOrders.value = orders;
    updateTableStatus(tableId, "Dining");
    if (!tableCountdownTimers.value.containsKey(tableId)) {
      startTableTimer(tableId, 10);
      updateKitchenStage(tableId, "Incoming");
    }
    _syncTableWithBills(tableId, existing);
  }

  void updateKitchenStage(int tableId, String stage) {
    Map<int, String> current = Map.from(tableKitchenStages.value);
    current[tableId] = stage;
    tableKitchenStages.value = current;
  }

  void notifyWaiter(int tableId) {
    Map<int, bool> current = Map.from(tableReadyNotifications.value);
    current[tableId] = true;
    tableReadyNotifications.value = current;
  }

  void clearWaiterNotification(int tableId) {
    Map<int, bool> current = Map.from(tableReadyNotifications.value);
    current.remove(tableId);
    tableReadyNotifications.value = current;
  }

  void addStaff(Map<String, dynamic> staff) {
    List<Map<String, dynamic>> current = List.from(staffDirectory.value);
    current.add(staff);
    staffDirectory.value = current;
  }

  void updateInventory(String item, double newAmount) {
    Map<String, dynamic> current = Map.from(inventoryStock.value);
    if (current.containsKey(item)) {
      current[item]['amount'] = newAmount;
      if (newAmount < 5) {
        current[item]['status'] = 'Critical';
      } else if (newAmount < 15) {
        current[item]['status'] = 'Low';
      } else {
        current[item]['status'] = 'Normal';
      }
      inventoryStock.value = current;
    }
  }

  void removeFromTableOrder(int tableId, String itemTitle) {
    Map<int, List<CartItem>> orders = Map.from(tableOrders.value);
    List<CartItem> existing = List.from(orders[tableId] ?? []);
    existing.removeWhere((item) => item.product.title == itemTitle);
    if (existing.isEmpty) {
      settleTable(tableId);
    } else {
      orders[tableId] = existing;
      tableOrders.value = orders;
      _syncTableWithBills(tableId, existing);
    }
  }

  void _syncTableWithBills(int tableId, List<CartItem> items) {
    List<Map<String, dynamic>> bills = List.from(allHistoricalBills.value);
    String tableStr = "Table $tableId";
    int existingIdx = bills.indexWhere((b) => b['table'] == tableStr && b['status'] == 'Active');
    double totalValue = 0;
    List<Map<String, dynamic>> billItems = [];
    for (var item in items) {
      String priceStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', '');
      double price = double.tryParse(priceStr) ?? 0;
      totalValue += price * item.quantity;
      billItems.add({'name': item.product.title, 'qty': item.quantity, 'price': item.product.price});
    }
    Map<String, dynamic> billData = {'id': existingIdx != -1 ? bills[existingIdx]['id'] : '${147 + bills.length}', 'table': tableStr, 'date': '20/08/2026', 'timestamp': existingIdx != -1 ? bills[existingIdx]['timestamp'] : DateTime.now(), 'time': existingIdx != -1 ? bills[existingIdx]['time'] : 'Now', 'items': billItems, 'total': 'NPR ${totalValue.toStringAsFixed(0)}', 'status': 'Active', 'server': 'Catherine'};
    if (existingIdx != -1) {
      bills[existingIdx] = billData;
    } else {
      bills.insert(0, billData);
    }
    allHistoricalBills.value = bills;
  }

  void clearTable(int tableId) {
    Map<int, List<CartItem>> orders = Map.from(tableOrders.value);
    orders.remove(tableId);
    tableOrders.value = orders;
    Map<int, List<CartItem>> confirmed = Map.from(confirmedTableOrders.value);
    confirmed.remove(tableId);
    confirmedTableOrders.value = confirmed;
    Map<int, DateTime> times = Map.from(tableStartTimes.value);
    times.remove(tableId);
    tableStartTimes.value = times;
    updateTableStatus(tableId, "Available");
  }

  Future<Map<String, dynamic>> confirmTableOrderWithResult(int tableId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return {"success": false, "message": "No tenant identified. Please refresh app."};
    final List<CartItem> newItems = tableOrders.value[tableId] ?? [];
    if (newItems.isEmpty) return {"success": false, "message": "Cart is empty."};
    double total = 0;
    List<Map<String, dynamic>> itemsJson = [];
    for (var item in newItems) {
      double prc = double.tryParse(item.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      total += prc * item.quantity;
      itemsJson.add({"name": item.product.title, "quantity": item.quantity, "price": prc});
    }
    final result = await ApiService.placeTableOrder({"tenant_id": tenant.id, "table_number": tableId, "total_amount": total, "items": itemsJson});
    if (result != null && result['status'] == 'success') {
      Map<int, List<CartItem>> allConfirmed = Map.from(confirmedTableOrders.value);
      List<CartItem> existing = List.from(allConfirmed[tableId] ?? []);
      existing.addAll(newItems);
      allConfirmed[tableId] = existing;
      confirmedTableOrders.value = allConfirmed;
      Map<int, List<CartItem>> currentOrders = Map.from(tableOrders.value);
      currentOrders.remove(tableId);
      tableOrders.value = currentOrders;
      return {"success": true};
    }
    return {"success": false, "message": result != null ? result['message'] : "Server connection failed."};
  }

  double getTableTotal(int tableId) {
    List<CartItem>? items = tableOrders.value[tableId];
    if (items == null) return 0;
    double total = 0;
    for (var item in items) {
      String priceStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', '');
      double price = double.tryParse(priceStr) ?? 0;
      total += price * item.quantity;
    }
    return total;
  }

  void createMusicPoll(String title, List<Map<String, dynamic>> songs) {
    activePoll.value = {'title': title, 'options': songs.map((s) => {...s, 'votes': 0}).toList(), 'endTime': DateTime.now().add(const Duration(minutes: 5)), 'userVotedIndex': -1, 'totalVotes': 0};
  }

  void castPollVote(int optionIndex) {
    if (activePoll.value == null || activePoll.value!['userVotedIndex'] != -1) return;
    Map<String, dynamic> poll = Map.from(activePoll.value!);
    List<dynamic> options = List.from(poll['options']);
    options[optionIndex]['votes'] += 1;
    poll['options'] = options;
    poll['totalVotes'] += 1;
    poll['userVotedIndex'] = optionIndex;
    activePoll.value = poll;
    vibeScore.value = (vibeScore.value + 3).clamp(0, 100);
  }

  void endPoll() {
    activePoll.value = null;
  }

  final ValueNotifier<List<Map<String, dynamic>>> musicQueue = ValueNotifier<List<Map<String, dynamic>>>([
    {'title': 'Blinding Lights', 'artist': 'The Weeknd', 'image': 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=500&auto=format&fit=crop&q=60', 'votes': 12, 'hasVoted': false, 'dedication': 'For Table 12'},
    {'title': 'Levitating', 'artist': 'Dua Lipa', 'image': 'https://images.unsplash.com/photo-1493225255756-d9584f8606e9?w=500&auto=format&fit=crop&q=60', 'votes': 8, 'hasVoted': false, 'dedication': 'To my best friend!'},
    {'title': 'Heat Waves', 'artist': 'Glass Animals', 'image': 'https://images.unsplash.com/photo-1557672172-298e090bd0f1?w=500&auto=format&fit=crop&q=60', 'votes': 5, 'hasVoted': false, 'dedication': null},
  ]);

  void toggleMusicVote(int index) {
    List<Map<String, dynamic>> queue = List.from(musicQueue.value);
    bool currentVoted = queue[index]['hasVoted'];
    queue[index]['hasVoted'] = !currentVoted;
    queue[index]['votes'] += currentVoted ? -1 : 1;
    queue.sort((a, b) => b['votes'].compareTo(a['votes']));
    musicQueue.value = queue;
    if (!currentVoted) vibeScore.value = (vibeScore.value + 2).clamp(0, 100);
  }

  void requestSong(String title, String artist, String? dedication) {
    List<Map<String, dynamic>> queue = List.from(musicQueue.value);
    queue.add({'title': title, 'artist': artist, 'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60', 'votes': 1, 'hasVoted': true, 'dedication': dedication});
    queue.sort((a, b) => b['votes'].compareTo(a['votes']));
    musicQueue.value = queue;
    vibeScore.value = (vibeScore.value + 5).clamp(0, 100);
  }

  void requestService(String type) {
    if (type == 'water') {
      isWaterRequested.value = true;
      _startCooldown('water');
    } else {
      isWaiterRequested.value = true;
      _startCooldown('waiter');
    }
  }

  void _startCooldown(String type) {
    final notifier = type == 'water' ? waterCooldown : waiterCooldown;
    final boolNotifier = type == 'water' ? isWaterRequested : isWaiterRequested;
    notifier.value = 120;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (notifier.value > 0) {
        notifier.value--;
      } else {
        boolNotifier.value = false;
        timer.cancel();
      }
    });
  }

  bool isMysteryBoxTime() {
    final hour = DateTime.now().hour;
    return hour >= 8 && hour < 20;
  }

  void addMembersToGroup(List<Map<String, dynamic>> members) {
    currentGroupMembers.addAll(members);
    final bonus = int.tryParse(loyaltySettings.value?['group_join_bonus']?.toString() ?? '200') ?? 200;
    groupCoins.value += (members.length * bonus);
    final tenant = TenantService().currentTenant.value;
    final staff = TenantService().currentStaff.value;
    final uid = staff != null ? staff.id.toString() : guestId.value;
    if (tenant != null && uid.isNotEmpty) {
      ApiService.addPoints(tenant.id, uid, points: members.length * bonus, incrementStamps: 0); 
      userPoints.value += (members.length * bonus);
    }
    isGroupActive.value = true;
  }

  void resetGroup() {
    isGroupActive.value = false;
    currentGroupMembers.clear();
  }

  final List<Map<String, dynamic>> nearbyUsers = [
    {'name': 'Mark', 'location': 'Table 12 (Lounge)', 'distance': '2m away', 'time': 'Since 3:12 pm', 'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500&auto=format&fit=crop&q=60', 'status': 'Eating Brisket', 'battery': '92%', 'isFollowing': true, 'isFollowingMe': true, 'lastMsg': 'Voice Note (0:12)', 'unread': 0, 'isOnline': false, 'activeTable': null},
    {'name': 'Noah', 'location': 'Table 4 (Window)', 'distance': '5m away', 'time': 'Since 4:45 pm', 'image': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=500&auto=format&fit=crop&q=60', 'status': 'Waiting for Order', 'battery': '45%', 'isFollowing': true, 'isFollowingMe': true, 'lastMsg': 'Come say hi later!', 'unread': 2, 'isOnline': true, 'activeTable': 'Table 4'},
    {'name': 'Sarah', 'location': 'Counter Bar', 'distance': '1m away', 'time': 'Since 5:30 pm', 'image': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=500&auto=format&fit=crop&q=60', 'status': 'Drinking Coffee', 'battery': '88%', 'isFollowing': false, 'isFollowingMe': false, 'lastMsg': '', 'unread': 0, 'isOnline': true},
    {'name': 'Emily', 'location': 'Outdoor Patio', 'distance': '15m away', 'time': 'Since 6:00 pm', 'image': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=500&auto=format&fit=crop&q=60', 'status': 'Reading Book', 'battery': '70%', 'isFollowing': false, 'isFollowingMe': false, 'lastMsg': '', 'unread': 0, 'isOnline': false},
  ];

  List<Map<String, dynamic>> get mutualFriends => nearbyUsers.where((user) => (user['isFollowing'] ?? false) && (user['isFollowingMe'] ?? false)).toList();

  int get cartCount {
    int count = 0;
    for (var item in items.value) {
      count += item.quantity;
    }
    return count;
  }

  double get totalPrice {
    double total = 0;
    for (var item in items.value) {
      String priceStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', '');
      double price = double.tryParse(priceStr) ?? 0;
      total += price * item.quantity;
    }
    return total;
  }

  void pushToCart({required Product product, required int quantity}) {
    List<CartItem> currentItems = List.from(items.value);
    int index = currentItems.indexWhere((i) => i.product.title == product.title);
    if (index != -1) {
      currentItems[index].quantity += quantity;
    } else {
      currentItems.add(CartItem(product: product, quantity: quantity));
    }
    items.value = currentItems;
  }

  void removeFromCart(Product product) {
    List<CartItem> currentItems = List.from(items.value);
    currentItems.removeWhere((i) => i.product.title == product.title);
    items.value = currentItems;
  }

  void updateQuantity(Product product, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(product);
      return;
    }
    List<CartItem> currentItems = List.from(items.value);
    int index = currentItems.indexWhere((i) => i.product.title == product.title);
    if (index != -1) {
      currentItems[index].quantity = newQuantity;
      items.value = currentItems;
    }
  }

  Timer? _statusTimer;

  Future<void> placeOrder() async {
    if (items.value.isEmpty) return;
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    double total = totalPrice;
    final List<Map<String, dynamic>> itemsJson = items.value.map((i) => {"name": i.product.title, "quantity": i.quantity, "price": double.tryParse(i.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0}).toList();
    if (selectedTableId.value == null) return;
    final String myUid = currentUserId;
    final result = await ApiService.placeTableOrder({"tenant_id": tenant.id, "table_number": selectedTableId.value, "user_id": myUid, "customer_email": customerEmail.value, "total_amount": total, "items": itemsJson});
    if (result != null && result['status'] == 'success') {
      int orderId = int.parse(result['order_id'].toString());
      placedOrderItems.value = List.from(items.value);
      activeOrderId.value = orderId;
      await _persistOrder(orderId);
      if (myUid.isNotEmpty) {
          await ApiService.addPoints(tenant.id, myUid, orderAmount: total);
          await refreshUserPoints();
          await updatePresenceOnServer();
          await fetchSocialLists();
      }
      clearCart();
      isOrderActive.value = true;
      orderStatus.value = OrderStatus.pending;
      _startStatusSync();
    }
  }

  void _startStatusSync() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (activeOrderId.value == null || !isOrderActive.value) {
        timer.cancel();
        return;
      }
      final liveStatus = await ApiService.fetchOrderStatus(activeOrderId.value!);
      if (liveStatus != null) {
        _mapStatus(liveStatus);
      }
    });
  }

  void _mapStatus(String dbStatus) {
    switch (dbStatus) {
      case 'Pending': orderStatus.value = OrderStatus.pending; break;
      case 'Approved': orderStatus.value = OrderStatus.approved; break;
      case 'Preparing': orderStatus.value = OrderStatus.preparing; break;
      case 'Ready': orderStatus.value = OrderStatus.ready; break;
      case 'Completed': clearActiveOrder(); break;
    }
  }

  Future<void> clearActiveOrder() async {
    isOrderActive.value = false;
    activeOrderId.value = null;
    placedOrderItems.value = [];
    orderStatus.value = OrderStatus.pending;
    _statusTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_order_ids');
    activeOrderIds.value = [];
  }

  void clearCart() => items.value = [];

  void addGameTime(Duration sessionTime) => totalGameTime.value += sessionTime;

  void switchTable(int id) => selectedTableId.value = id;

  int getItemQuantity(String title) {
    final index = items.value.indexWhere((i) => i.product.title == title);
    return index != -1 ? items.value[index].quantity : 0;
  }

  void navigateToCategory(String? category) {
    activeCategory.value = category;
    currentTabIndex.value = 1;
  }
}

final storeManager = ShopManager();
