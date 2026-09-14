import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

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
    _startMusicPoller();
    _initPushListeners();
    _startNearbyMonitor();
    _startOrderSyncPoller();
    _startChatPoller();
    
    currentTabIndex.addListener(_persistTab);
    selectedTableId.addListener(_persistTable);
    isProfileVisible.addListener(updatePrivacyOnServer);
    isWaveEnabled.addListener(updatePrivacyOnServer);
    showTableNumber.addListener(_persistGenericSettings);
    onlyMutualChat.addListener(_persistGenericSettings);
    autoWaveBack.addListener(_persistGenericSettings);
    socialVibration.addListener(_persistGenericSettings);
  }

  void _persistGenericSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_table_number', showTableNumber.value);
    await prefs.setBool('only_mutual_chat', onlyMutualChat.value);
    await prefs.setBool('auto_wave_back', autoWaveBack.value);
    await prefs.setBool('social_vibration', socialVibration.value);
    await prefs.setBool('is_profile_visible', isProfileVisible.value);
    await prefs.setBool('is_wave_enabled', isWaveEnabled.value);
  }

  int _lastOrderSyncTimestamp = 0;
  Timer? _orderSyncTimer;

  void _startOrderSyncPoller() {
    _orderSyncTimer?.cancel();
    _orderSyncTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      final tenant = TenantService().currentTenant.value;
      if (tenant == null) return;

      final serverTimestamp = await ApiService.checkOrderChange(tenant.id);
      if (serverTimestamp > _lastOrderSyncTimestamp) {
        await refreshLiveOrders();
        _lastOrderSyncTimestamp = serverTimestamp;
      }
    });
  }

  // --- CHAT POLLING ---
  Timer? _chatTimer;
  final ValueNotifier<List<Map<String, dynamic>>> conversations = ValueNotifier([]);

  void _startChatPoller() {
    _chatTimer?.cancel();
    _chatTimer = Timer.periodic(const Duration(seconds: 20), (timer) => refreshConversations());
  }

  Future<void> refreshConversations() async {
    final tenant = TenantService().currentTenant.value;
    final uid = currentUserId;
    if (tenant == null || uid.isEmpty) return;

    final data = await ApiService.fetchConversations(tenant.id, uid);
    if (data != null) {
      conversations.value = data;
    }
  }

  Future<void> refreshLiveOrders() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final List<Map<String, dynamic>>? orders = await ApiService.fetchActiveOrders(tenant.id);
    if (orders == null) return;

    Map<int, String> newStatuses = Map.from(tableStatuses.value);
    Map<int, List<CartItem>> newOrders = {};

    for (var order in orders) {
      int tNum = int.tryParse(order['table_number']?.toString() ?? '') ?? 0;
      if (tNum == 0) continue;

      String status = order['status'] ?? 'Pending';
      if (status == 'Pending') newStatuses[tNum] = 'NEW ORDER';
      else if (status == 'Ready') newStatuses[tNum] = 'READY';
      else newStatuses[tNum] = 'Dining';

      final List<dynamic> rawItems = order['items'] ?? [];
      final List<CartItem> itemsList = rawItems.map((i) => CartItem(
        product: Product(title: i['product_name'] ?? 'Item', price: i['price_at_order']?.toString() ?? '0', image: '', tag: 'Real', rating: '5.0'),
        quantity: int.tryParse(i['quantity']?.toString() ?? '1') ?? 1,
      )).toList();

      newOrders[tNum] = itemsList;
    }

    tableStatuses.value = newStatuses;
    tableOrders.value = newOrders;
  }

  void _persistTab() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_tab_index', currentTabIndex.value);
  }

  void _persistTable() async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedTableId.value != null) await prefs.setInt('selected_table_id', selectedTableId.value!);
    else await prefs.remove('selected_table_id');
  }

  void _startMusicPoller() {
    Timer.periodic(const Duration(seconds: 30), (timer) => refreshMusicStatus());
  }

  Future<void> refreshMusicStatus() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final data = await ApiService.fetchMusicStatus(tenant.id, userId: currentUserId);
    if (data != null && data['status'] == 'success') {
      if (data['now_playing'] != null) currentSong.value = Map<String, dynamic>.from(data['now_playing']);
      if (data['queue'] != null) musicQueue.value = List<Map<String, dynamic>>.from(data['queue']);
      if (data['active_poll'] != null) activePoll.value = Map<String, dynamic>.from(data['active_poll']);
      else activePoll.value = null;
    }
  }

  void _startNearbyMonitor() {
    Timer.periodic(const Duration(minutes: 5), (timer) => checkProximity());
    Future.delayed(const Duration(seconds: 5), () => checkProximity());
  }

  final ValueNotifier<bool> isNearbyOfferVisible = ValueNotifier<bool>(false);
  DateTime? _lastOfferTime;

  Future<void> checkProximity() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || tenant.latitude == null || tenant.longitude == null) return;
    if (_lastOfferTime != null && DateTime.now().difference(_lastOfferTime!).inHours < 12) return;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) return;
      Position pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      double dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, tenant.latitude!, tenant.longitude!);
      if (dist <= 600) {
        _lastOfferTime = DateTime.now();
        isNearbyOfferVisible.value = true;
      }
    } catch (e) {}
  }

  void _initPushListeners() {
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          refreshNotifications();
          refreshConversations(); 
        });
      }
    } catch (e) {}
  }

  void _startNotificationsPoller() {
    Timer.periodic(const Duration(seconds: 45), (timer) => refreshNotifications());
  }

  final ValueNotifier<int> unseenNotificationsCount = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> notificationsList = ValueNotifier<List<Map<String, dynamic>>>([]);

  Future<void> refreshNotifications() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return;
    final data = await ApiService.fetchNotifications(tenant.id, currentUserId);
    if (data != null && data['status'] == 'success') {
      notificationsList.value = List<Map<String, dynamic>>.from(data['data'] ?? []);
      unseenNotificationsCount.value = data['unseen_count'] ?? 0;
    }
  }

  Future<void> clearNotificationBadge() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return;
    if (await ApiService.markNotificationsRead(tenant.id, currentUserId)) {
      unseenNotificationsCount.value = 0;
    }
  }

  void _startWavePoller() {
    Timer.periodic(const Duration(seconds: 20), (timer) async {
      final tenant = TenantService().currentTenant.value;
      if (tenant != null && currentUserId.isNotEmpty) {
        final waves = await ApiService.fetchWaves(tenant.id, currentUserId);
        if (waves != null && waves.isNotEmpty) HapticFeedback.vibrate();
      }
    });
  }

  void _startPresenceCheckIn() {
    Timer.periodic(const Duration(minutes: 2), (timer) => updatePresenceOnServer());
  }

  Future<void> updatePresenceOnServer() async {
    final tenant = TenantService().currentTenant.value;
    // Only update if we have a tenant, a user ID, and a locked-in table number
    // This prevents "anonymous ghost" updates from overloading the server
    if (tenant != null && currentUserId.isNotEmpty && selectedTableId.value != null && selectedTableId.value! > 0) {
      await ApiService.updatePresence(
        tenantId: tenant.id, 
        userId: currentUserId, 
        tableNumber: selectedTableId.value!, 
        userName: customerName.value.isNotEmpty ? customerName.value : null
      );
    }
  }

  Future<void> updatePrivacyOnServer() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant != null && currentUserId.isNotEmpty) {
      await ApiService.updatePrivacySettings(tenantId: tenant.id, userId: currentUserId, isPublic: isProfileVisible.value, allowWaves: isWaveEnabled.value);
    }
  }

  Future<void> _loadPersistedOrder() async {
    final prefs = await SharedPreferences.getInstance();
    isOnboardingComplete.value = prefs.getBool('onboarding_complete') ?? false;
    currentTabIndex.value = prefs.getInt('last_tab_index') ?? 0;
    final int? savedTable = prefs.getInt('selected_table_id');
    if (savedTable != null) selectedTableId.value = savedTable;
    showTableNumber.value = prefs.getBool('show_table_number') ?? true;
    onlyMutualChat.value = prefs.getBool('only_mutual_chat') ?? false;
    autoWaveBack.value = prefs.getBool('auto_wave_back') ?? false;
    socialVibration.value = prefs.getBool('social_vibration') ?? true;
    isProfileVisible.value = prefs.getBool('is_profile_visible') ?? true;
    isWaveEnabled.value = prefs.getBool('is_wave_enabled') ?? true;

    // LOAD PERSISTED GROUP SESSION
    final int? sid = prefs.getInt('active_session_id');
    if (sid != null) {
      final bool isHost = prefs.getBool('is_session_host') ?? false;
      final String? pin = prefs.getString('active_session_pin');
      startSessionPolling(sid, isHost, pin: pin);
    }

    String? savedEmail = prefs.getString('customer_email');
    if (savedEmail != null) await syncCustomerIdentity(savedEmail);
    else Future.delayed(const Duration(seconds: 2), () => isEmailSynced.value = false);

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
    await fetchSocialLists();
    checkNotificationPermission();
  }

  Future<void> _persistOrder(int id, {bool isRemove = false}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> current = prefs.getStringList('active_order_ids') ?? [];
    if (isRemove) current.remove(id.toString());
    else if (!current.contains(id.toString())) current.add(id.toString());
    await prefs.setStringList('active_order_ids', current);
    activeOrderIds.value = current.map((e) => int.parse(e)).toList();
  }

  void _startGlobalTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (tableCountdownTimers.value.isNotEmpty) {
        Map<int, int> current = Map.from(tableCountdownTimers.value);
        bool changed = false;
        current.forEach((id, seconds) { if (seconds > 0) { current[id] = seconds - 1; changed = true; } });
        if (changed) tableCountdownTimers.value = current;
      }
    });
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

  // --- VARIABLES ---
  final ValueNotifier<List<CartItem>> items = ValueNotifier<List<CartItem>>([]);
  final ValueNotifier<List<CartItem>> placedOrderItems = ValueNotifier<List<CartItem>>([]);
  final ValueNotifier<int> currentTabIndex = ValueNotifier<int>(0);
  final ValueNotifier<bool> isQrLaunch = ValueNotifier<bool>(false);
  final ValueNotifier<int?> selectedTableId = ValueNotifier<int?>(null);
  final ValueNotifier<String> guestId = ValueNotifier<String>('');
  final ValueNotifier<String> customerEmail = ValueNotifier<String>('');
  final ValueNotifier<String> customerName = ValueNotifier<String>('');
  final ValueNotifier<bool> needsPin = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isEmailSynced = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isNewToShop = ValueNotifier<bool>(false);
  final ValueNotifier<String> userGender = ValueNotifier<String>('Male');
  final ValueNotifier<bool> isProfileVisible = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isWaveEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isOnboardingComplete = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showNotificationPrompt = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isConnectedToRestaurantWiFi = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isOrderPaid = ValueNotifier<bool>(false);

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
  final ValueNotifier<int> followersCount = ValueNotifier<int>(0);
  final ValueNotifier<int> followingCount = ValueNotifier<int>(0);
  final ValueNotifier<int> connectionsCount = ValueNotifier<int>(0);

  // --- SOCIAL METHODS ---
  Future<bool> toggleFollow(String targetId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant != null && currentUserId.isNotEmpty && currentUserId != targetId) {
      if ((await ApiService.toggleFollow(tenantId: tenant.id, myId: currentUserId, targetId: targetId))['success'] == true) {
        await refreshSocialStats();
        await fetchSocialLists();
        return true;
      }
    }
    return false;
  }

  Future<void> refreshSocialStats() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant != null && currentUserId.isNotEmpty) {
      final data = await ApiService.fetchSocialStats(tenant.id, currentUserId);
      if (data != null && data['status'] == 'success') {
        followersCount.value = data['followers'] ?? 0;
        followingCount.value = data['following'] ?? 0;
        connectionsCount.value = data['connections'] ?? 0;
      }
    }
  }

  final ValueNotifier<List<Map<String, dynamic>>> followingList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> requestsList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> friendsList = ValueNotifier([]);

  Future<void> fetchSocialLists() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return;
    final following = await ApiService.fetchSocialList(action: 'get_following', tenantId: tenant.id, userId: currentUserId);
    final requests = await ApiService.fetchSocialList(action: 'get_requests', tenantId: tenant.id, userId: currentUserId);
    final friends = await ApiService.fetchSocialList(action: 'get_friends', tenantId: tenant.id, userId: currentUserId);
    if (following != null) followingList.value = List<Map<String, dynamic>>.from(following);
    if (requests != null) requestsList.value = List<Map<String, dynamic>>.from(requests);
    if (friends != null) friendsList.value = List<Map<String, dynamic>>.from(friends);
    final orderData = await ApiService.fetchUserOrders(tenant.id, currentUserId);
    if (orderData != null) totalOrdersCount.value = orderData['total_count'] ?? 0;
  }

  // --- LOYALTY ---
  final ValueNotifier<int> userPoints = ValueNotifier<int>(0);
  final ValueNotifier<int> orderStampCount = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, dynamic>?> loyaltySettings = ValueNotifier<Map<String, dynamic>?>(null);

  Future<void> fetchLoyaltySettings() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final settings = await ApiService.fetchLoyaltySettings(tenant.id);
    if (settings != null) loyaltySettings.value = settings;
  }

  Future<void> refreshUserPoints() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return;
    final response = await http.get(Uri.parse("${ApiService.baseUrl}/loyalty_api.php?action=get_points&user_id=$currentUserId&tenant_id=${tenant.id}"));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        userPoints.value = data['points'] ?? 0;
        orderStampCount.value = data['order_count'] ?? 0;
      }
    }
  }

  // --- MUSIC ---
  final ValueNotifier<List<Map<String, dynamic>>> musicQueue = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<Map<String, dynamic>> currentSong = ValueNotifier<Map<String, dynamic>>({'title': 'No Song Playing', 'artist': '-', 'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500', 'progress': 0.0});
  final ValueNotifier<int> vibeScore = ValueNotifier<int>(50);
  final ValueNotifier<Map<String, dynamic>?> activePoll = ValueNotifier<Map<String, dynamic>?>(null);

  Future<Map<String, dynamic>> toggleMusicVote(int songId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return {"success": false};
    final result = await ApiService.voteSong(tenantId: tenant.id, userId: currentUserId, songId: songId);
    if (result['status'] == 'success') { await refreshMusicStatus(); vibeScore.value = (vibeScore.value + 2).clamp(0, 100); return {"success": true}; }
    return {"success": false};
  }

  Future<Map<String, dynamic>> requestSong(String title, String artist, String? dedication) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return {"success": false};
    final result = await ApiService.requestMusic({'tenant_id': tenant.id, 'title': title, 'artist': artist, 'dedication': dedication, 'user_id': currentUserId});
    if (result['success'] == true) { await refreshMusicStatus(); vibeScore.value = (vibeScore.value + 5).clamp(0, 100); }
    return result;
  }

  void createMusicPoll(String title, List<Map<String, dynamic>> songs) { activePoll.value = {'title': title, 'options': songs.map((s) => {...s, 'votes': 0}).toList(), 'endTime': DateTime.now().add(const Duration(minutes: 5)), 'userVotedIndex': -1, 'totalVotes': 0}; }
  void castPollVote(int optionIndex) {
    if (activePoll.value == null || activePoll.value!['userVotedIndex'] != -1) return;
    Map<String, dynamic> poll = Map.from(activePoll.value!);
    List<dynamic> opts = List.from(poll['options']); opts[optionIndex]['votes'] += 1;
    poll['options'] = opts; poll['totalVotes'] += 1; poll['userVotedIndex'] = optionIndex;
    activePoll.value = poll;
  }

  // --- TABLES & ORDERS ---
  final ValueNotifier<Map<int, List<CartItem>>> tableOrders = ValueNotifier({});
  final ValueNotifier<Map<int, List<CartItem>>> confirmedTableOrders = ValueNotifier({});
  final ValueNotifier<Map<int, String>> tableStatuses = ValueNotifier({});
  final ValueNotifier<Map<int, String>> tableKitchenStages = ValueNotifier({});
  final ValueNotifier<Map<int, bool>> tableReadyNotifications = ValueNotifier({});
  final ValueNotifier<Map<int, DateTime>> tableStartTimes = ValueNotifier({});
  final ValueNotifier<Map<int, int>> tableCountdownTimers = ValueNotifier({});
  final ValueNotifier<Map<int, int>> tableOriginalDurations = ValueNotifier({});

  void initializeTables(int count) { if (tableStatuses.value.isEmpty) { Map<int, String> initial = {}; for (int i = 1; i <= count; i++) initial[i] = "Available"; tableStatuses.value = initial; } }
  void updateTableStatus(int tableId, String status) { tableStatuses.value = Map.from(tableStatuses.value)..[tableId] = status; }
  void settleTable(int tableId) { updateTableStatus(tableId, "Available"); tableOrders.value = Map.from(tableOrders.value)..remove(tableId); confirmedTableOrders.value = Map.from(confirmedTableOrders.value)..remove(tableId); }
  void clearTable(int tableId) => settleTable(tableId);
  void addOrderToTable(int tableId, List<CartItem> newItems) {
    Map<int, List<CartItem>> orders = Map.from(tableOrders.value); List<CartItem> existing = List.from(orders[tableId] ?? []);
    for (var newItem in newItems) { int idx = existing.indexWhere((i) => i.product.title == newItem.product.title); if (idx != -1) existing[idx].quantity += newItem.quantity; else existing.add(newItem); }
    orders[tableId] = existing; tableOrders.value = orders; updateTableStatus(tableId, "Dining");
  }
  void removeFromTableOrder(int tableId, String title) {
    Map<int, List<CartItem>> orders = Map.from(tableOrders.value); List<CartItem> existing = List.from(orders[tableId] ?? []);
    existing.removeWhere((i) => i.product.title == title); if (existing.isEmpty) settleTable(tableId); else { orders[tableId] = existing; tableOrders.value = orders; }
  }
  Future<Map<String, dynamic>> confirmTableOrderWithResult(int tableId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return {"success": false};
    final List<CartItem> newItems = tableOrders.value[tableId] ?? [];
    double total = 0; List<Map<String, dynamic>> itemsJson = [];
    for (var item in newItems) { double prc = double.tryParse(item.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0; total += prc * item.quantity; itemsJson.add({"name": item.product.title, "quantity": item.quantity, "price": prc}); }
    final result = await ApiService.placeTableOrder({"tenant_id": tenant.id, "table_number": tableId, "user_id": currentUserId, "total_amount": total, "items": itemsJson});
    if (result != null && result['status'] == 'success') {
       final Map<int, List<CartItem>> updated = Map.from(confirmedTableOrders.value);
       updated[tableId] = (updated[tableId] ?? [])..addAll(newItems);
       confirmedTableOrders.value = updated; tableOrders.value = Map.from(tableOrders.value)..remove(tableId); return {"success": true};
    }
    return {"success": false};
  }

  static int parseTableId(String str) => int.tryParse(str.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  void clearWaiterNotification(int id) => tableReadyNotifications.value = Map.from(tableReadyNotifications.value)..remove(id);

  // --- IDENTITY ---
  Future<void> syncCustomerIdentity(String email, {String? name}) async {
    final tenant = TenantService().currentTenant.value; if (tenant == null) return;
    final res = await ApiService.syncCustomerProfile(tenantId: tenant.id, email: email, name: name);
    if (res != null && res['status'] == 'success') {
      customerEmail.value = email; customerName.value = res['user']?['name'] ?? 'Guest'; needsPin.value = res['needs_pin'] == true; isNewToShop.value = res['is_new_to_shop'] == true; isEmailSynced.value = true; userPoints.value = res['user']?['points'] ?? 0; orderStampCount.value = res['user']?['order_count'] ?? 0;
      isProfileVisible.value = (res['user']?['is_public'] == 1 || res['user']?['is_public'] == true); isWaveEnabled.value = (res['user']?['allow_waves'] == 1 || res['user']?['allow_waves'] == true);
      final prefs = await SharedPreferences.getInstance(); await prefs.setString('customer_email', email);
    }
  }

  Future<bool> finalizeSecurityPin(String pin) async {
    final tenant = TenantService().currentTenant.value; if (tenant == null || customerEmail.value.isEmpty) return false;
    if (await ApiService.saveCustomerPin(tenantId: tenant.id, email: customerEmail.value, pin: pin)) { needsPin.value = false; await fetchSocialLists(); return true; }
    return false;
  }

  Future<bool> updateProfile({required String name, required String gender, bool isAnon = false}) async {
    final tenant = TenantService().currentTenant.value; if (tenant == null || currentUserId.isEmpty) return false;
    if (await ApiService.submitOnboarding(tenantId: tenant.id, userId: currentUserId, name: name, gender: gender, isAnonymous: isAnon)) {
      customerName.value = name; userGender.value = gender; isOnboardingComplete.value = true;
      final prefs = await SharedPreferences.getInstance(); await prefs.setBool('onboarding_complete', true);
      await refreshSocialStats(); await fetchSocialLists(); await setupPushNotifications(); return true;
    }
    return false;
  }

  Future<void> checkNotificationPermission() async {
    try {
      if (Firebase.apps.isEmpty) return; final prefs = await SharedPreferences.getInstance(); if (prefs.getBool('notif_prompt_dismissed') == true) return;
      FirebaseMessaging messaging = FirebaseMessaging.instance; NotificationSettings settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) showNotificationPrompt.value = true;
      else if (settings.authorizationStatus == AuthorizationStatus.authorized) setupPushNotifications();
    } catch (e) {}
  }

  Future<bool> setupPushNotifications() async {
    final tenant = TenantService().currentTenant.value; if (tenant == null || currentUserId.isEmpty) return false;
    try {
      if (Firebase.apps.isEmpty) return false; FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await (kIsWeb ? messaging.getToken(vapidKey: 'BGfucW_HKKPEUrswHLq1S-WGdeyHv6jTkSGvsJ_bP20OelPwEpMcsxAkhpf34iK3g-H1E8NVVY8Vo96bIyxagQg') : messaging.getToken());
        if (token != null) { await ApiService.updateFcmToken(tenantId: tenant.id, userId: currentUserId, token: token); final prefs = await SharedPreferences.getInstance(); await prefs.setBool('notif_prompt_dismissed', true); return true; }
      }
    } catch (e) {} finally { showNotificationPrompt.value = false; }
    return false;
  }

  Future<void> syncProcurementData(String tenantId) async {
    final supData = await ApiService.fetchSuppliers(tenantId); final purData = await ApiService.fetchPurchases(tenantId);
    if (supData != null) allSuppliers.value = List<Map<String, dynamic>>.from(supData); if (purData != null) allPurchases.value = List<Map<String, dynamic>>.from(purData);
  }

  final ValueNotifier<List<Map<String, dynamic>>> allPurchases = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> allSuppliers = ValueNotifier([]);

  // --- OTHERS ---
  final ValueNotifier<bool> onlyMutualChat = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showTableNumber = ValueNotifier<bool>(true);
  final ValueNotifier<bool> socialVibration = ValueNotifier<bool>(true);
  final ValueNotifier<bool> autoWaveBack = ValueNotifier<bool>(false);
  bool isMysteryBoxTime() { final h = DateTime.now().hour; return h >= 8 && h < 22; }
  int getItemQuantity(String title) { final idx = items.value.indexWhere((i) => i.product.title == title); return idx != -1 ? items.value[idx].quantity : 0; }
  void pushToCart({required Product product, required int quantity}) { List<CartItem> curr = List.from(items.value); int idx = curr.indexWhere((i) => i.product.title == product.title); if (idx != -1) curr[idx].quantity += quantity; else curr.add(CartItem(product: product, quantity: quantity)); items.value = curr; }
  void removeFromCart(Product p) { items.value = List<CartItem>.from(items.value)..removeWhere((i) => i.product.title == p.title); }
  void updateQuantity(Product p, int qty) { if (qty <= 0) removeFromCart(p); else { List<CartItem> curr = List.from(items.value); int idx = curr.indexWhere((i) => i.product.title == p.title); if (idx != -1) { curr[idx].quantity = qty; items.value = curr; } } }
  void clearCart() => items.value = [];
  void navigateToCategory(String? c) { activeCategory.value = c; currentTabIndex.value = 1; }
  void switchTable(int id) => selectedTableId.value = id;
  int get cartCount { int count = 0; for (var item in items.value) count += item.quantity; return count; }
  double get totalPrice { double total = 0; for (var item in items.value) { String prcStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', ''); total += (double.tryParse(prcStr) ?? 0) * item.quantity; } return total; }

  final ValueNotifier<List<Map<String, dynamic>>> allHistoricalBills = ValueNotifier([]);
  final ValueNotifier<Map<String, dynamic>> inventoryStock = ValueNotifier({});
  final ValueNotifier<List<Map<String, dynamic>>> staffDirectory = ValueNotifier([]);
  final ValueNotifier<int> waiterTabIndex = ValueNotifier(0);
  final ValueNotifier<Map<int, Map<String, CartItem>>> pendingTableOrders = ValueNotifier({});
  final ValueNotifier<int?> activeStaffTableId = ValueNotifier(null);
  final ValueNotifier<bool> isMysteryBoxOpened = ValueNotifier(false);
  final ValueNotifier<bool> isRewardClaimed = ValueNotifier(false);

  void setPendingItem(int tableId, Map<String, dynamic> p, int qty) {
    Map<int, Map<String, CartItem>> all = Map.from(pendingTableOrders.value); Map<String, CartItem> table = Map.from(all[tableId] ?? {}); String title = p['title'];
    if (qty <= 0) table.remove(title);
    else table[title] = CartItem(product: Product(title: p['title'], price: p['price'].toString(), image: p['image'] ?? '', tag: p['tag'] ?? "Staff", rating: p['rating'] ?? "N/A"), quantity: qty);
    all[tableId] = table; pendingTableOrders.value = all;
  }
  void clearPendingOrder(int id) => pendingTableOrders.value = Map.from(pendingTableOrders.value)..remove(id);

  Future<void> placeOrder() async {
    if (items.value.isEmpty || selectedTableId.value == null) return;
    double total = totalPrice; final itemsJson = items.value.map((i) => {"name": i.product.title, "quantity": i.quantity, "price": double.tryParse(i.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0}).toList();
    final result = await ApiService.placeTableOrder({"tenant_id": TenantService().currentTenant.value!.id, "table_number": selectedTableId.value, "user_id": currentUserId, "customer_email": customerEmail.value, "total_amount": total, "items": itemsJson});
    if (result != null && result['status'] == 'success') { 
      int id = int.parse(result['order_id'].toString()); 
      activeOrderId.value = id; 
      
      // AUTO-SYNC TO LIVE SESSION
      final List<Map<String, dynamic>> sessionUpdate = items.value.map((i) => {
        'title': i.product.title,
        'who': customerName.value.isNotEmpty ? customerName.value : "Host",
        'status': 'Kitchen',
        'price': i.product.price,
        'image': i.product.image,
      }).toList();
      liveSessionOrders.value = List.from(liveSessionOrders.value)..addAll(sessionUpdate);

      await _persistOrder(id); 
      clearCart(); 
      isOrderActive.value = true; 
      _startStatusSync(); 
    }
  }

  void _startStatusSync() {
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (activeOrderId.value == null) { timer.cancel(); return; }
      final live = await ApiService.fetchOrderStatus(activeOrderId.value!);
      if (live != null) {
        if (live == 'Pending') orderStatus.value = OrderStatus.pending;
        else if (live == 'Approved') orderStatus.value = OrderStatus.approved;
        else if (live == 'Preparing') orderStatus.value = OrderStatus.preparing;
        else if (live == 'Ready') orderStatus.value = OrderStatus.ready;
        else if (live == 'Completed') { isOrderActive.value = false; timer.cancel(); }
      }
    });
  }

  void _mapStatus(String dbStatus) {
    if (dbStatus == 'Pending') orderStatus.value = OrderStatus.pending;
    else if (dbStatus == 'Approved') orderStatus.value = OrderStatus.approved;
    else if (dbStatus == 'Preparing') orderStatus.value = OrderStatus.preparing;
    else if (dbStatus == 'Ready') orderStatus.value = OrderStatus.ready;
  }

  Future<void> clearActiveOrder() async { isOrderActive.value = false; activeOrderId.value = null; placedOrderItems.value = []; orderStatus.value = OrderStatus.pending; }

  // --- GAMIFICATION ---
  final ValueNotifier<int> tapWarTimer = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> tapLeaderboard = ValueNotifier<List<Map<String, dynamic>>>([]);
  void startTapWar() { tapWarTimer.value = 30; tapLeaderboard.value = [{'table': 'Your Table', 'score': 0, 'isUser': true}]; }
  void recordTap() { if (tapWarTimer.value > 0) { List<Map<String, dynamic>> curr = List.from(tapLeaderboard.value); curr[0]['score']++; tapLeaderboard.value = curr; } }
  void endTapWar() { tapWarTimer.value = 0; }
  void updateTableName(String old, String newN) { List<Map<String, dynamic>> curr = List.from(tapLeaderboard.value); for (var i in curr) if (i['table'] == old) i['table'] = newN; tapLeaderboard.value = curr; }
  void addGameTime(Duration d) { totalGameTime.value += d; }

  Future<Map<String, dynamic>> addPoints(String tenantId, String userId, {double orderAmount = 0, int points = 0, int incrementStamps = 0}) async {
    final result = await ApiService.addPoints(tenantId, userId, orderAmount: orderAmount, points: points, incrementStamps: incrementStamps);
    await refreshUserPoints();
    return result;
  }

  // --- GROUP DINING LIVE SYNC (V3 - Real Backend) ---
  final ValueNotifier<List<Map<String, dynamic>>> liveSessionOrders = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> liveSessionMembers = ValueNotifier([]);
  final ValueNotifier<double> liveSessionTotal = ValueNotifier(0.0);
  final ValueNotifier<bool> isSessionHost = ValueNotifier(false);
  final ValueNotifier<int?> activeSessionId = ValueNotifier(null);
  final ValueNotifier<String?> activeSessionPin = ValueNotifier<String?> (null);
  final ValueNotifier<bool> isSessionLocked = ValueNotifier(false);
  final ValueNotifier<String?> activeSessionQr = ValueNotifier<String?>(null);
  final ValueNotifier<bool> openTablePickerTrigger = ValueNotifier(false);
  final ValueNotifier<bool> isSplitShared = ValueNotifier(false);
  final ValueNotifier<String?> volunteerId = ValueNotifier<String?>(null);

  Timer? _sessionPoller;
  String? _lastSyncTime;

  void startSessionPolling(int sid, bool asHost, {String? pin}) async {
    if (pin != null) activeSessionPin.value = pin;
    activeSessionId.value = sid;
    isSessionHost.value = asHost;
    
    _lastSyncTime = null;
    _sessionPoller?.cancel();
    _sessionPoller = Timer.periodic(const Duration(seconds: 8), (timer) => syncSessionData());
    syncSessionData(); // Initial immediate sync

    // PERSIST SESSION
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_session_id', sid);
    await prefs.setBool('is_session_host', asHost);
    if (pin != null) await prefs.setString('active_session_pin', pin);
  }

  Future<void> syncSessionData() async {
    if (activeSessionId.value == null) return;
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final result = await ApiService.getSplitGroupDetails(
      tenantId: tenant.id, 
      sessionId: activeSessionId.value!,
      lastSyncTime: _lastSyncTime
    );

    if (result != null) {
      if (result['status'] == 'success') {
        final data = result['data'];
        liveSessionOrders.value = List<Map<String, dynamic>>.from(data['items'] ?? []);
        liveSessionMembers.value = List<Map<String, dynamic>>.from(data['members'] ?? []);
        liveSessionTotal.value = (data['total_bill'] ?? 0.0).toDouble();
        
        // CHECK FOR PAYMENT QR
        if (data['payment_qr'] != null && activeSessionQr.value == null) {
          activeSessionQr.value = data['payment_qr'];
          // Trigger Popup Notifier
          showPaymentPopup.value = true;
        }

        if (data['session_status'] == 'Locked') {
          isSessionLocked.value = true;
        }

        if (data['is_split_shared'] != null) {
          isSplitShared.value = data['is_split_shared'];
        }
        if (data['volunteer_id'] != null) {
          volunteerId.value = data['volunteer_id'];
        }

        _lastSyncTime = data['server_time'];
      } else if (result['status'] == 'no_change') {
        _lastSyncTime = result['server_time'];
      }
    }
  }

  final ValueNotifier<bool> showPaymentPopup = ValueNotifier(false);

  void resetSession() async {
    _sessionPoller?.cancel();
    liveSessionOrders.value = [];
    liveSessionMembers.value = [];
    liveSessionTotal.value = 0.0;
    isSessionHost.value = false;
    activeSessionId.value = null;
    activeSessionPin.value = null;
    isSessionLocked.value = false;
    _lastSyncTime = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session_id');
    await prefs.remove('is_session_host');
    await prefs.remove('active_session_pin');
  }

  // --- GROUP CHAT ---
  final List<Map<String, dynamic>> currentGroupMembers = [];
  final List<Map<String, dynamic>> nearbyUsers = [];
  void addMembersToGroup(List<Map<String, dynamic>> m) { currentGroupMembers.addAll(m); }
}

final storeManager = ShopManager();
