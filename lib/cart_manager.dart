import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';
import 'services/push_service_worker_stub.dart'
    if (dart.library.html) 'services/push_service_worker_web.dart';

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

  Future<void>? _initFuture;

  Future<void> ensureInitialized() async {
    _initFuture ??= _loadPersistedOrder();
    await _initFuture;
  }

  ShopManager._internal() {
    _startGlobalTimer();
    _initFuture = _loadPersistedOrder();
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
    _orderSyncTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
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
  final ValueNotifier<List<Map<String, dynamic>>> conversations = ValueNotifier(
    [],
  );
  final ValueNotifier<int> totalUnreadChatCount = ValueNotifier<int>(0);

  void _startChatPoller() {
    _chatTimer?.cancel();
    _chatTimer = Timer.periodic(
      const Duration(seconds: 20),
      (timer) => refreshConversations(),
    );
  }

  Future<void> refreshConversations() async {
    final tenant = TenantService().currentTenant.value;
    final uid = currentUserId;
    if (tenant == null || uid.isEmpty) return;

    final data = await ApiService.fetchConversations(tenant.id, uid);
    if (data != null) {
      conversations.value = data;

      // Calculate total unread count across all friends
      int count = 0;
      for (var chat in data) {
        count += (int.tryParse(chat['unread']?.toString() ?? '0') ?? 0);
      }
      totalUnreadChatCount.value = count;
    }
  }

  Future<void> refreshLiveOrders() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final List<Map<String, dynamic>>? orders =
        await ApiService.fetchActiveOrders(tenant.id);
    if (orders == null) return;

    Map<int, String> newStatuses = Map.from(tableStatuses.value);
    Map<int, List<CartItem>> newOrders = {};

    for (var order in orders) {
      int tNum = int.tryParse(order['table_number']?.toString() ?? '') ?? 0;
      if (tNum == 0) continue;

      String status = order['status'] ?? 'Pending';
      if (status == 'Pending')
        newStatuses[tNum] = 'NEW ORDER';
      else if (status == 'Ready')
        newStatuses[tNum] = 'READY';
      else
        newStatuses[tNum] = 'Dining';

      final List<dynamic> rawItems = order['items'] ?? [];
      final List<CartItem> itemsList = rawItems
          .map(
            (i) => CartItem(
              product: Product(
                title: i['product_name'] ?? 'Item',
                price: i['price_at_order']?.toString() ?? '0',
                image: '',
                tag: 'Real',
                rating: '5.0',
              ),
              quantity: int.tryParse(i['quantity']?.toString() ?? '1') ?? 1,
            ),
          )
          .toList();

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
    if (selectedTableId.value != null)
      await prefs.setInt('selected_table_id', selectedTableId.value!);
    else
      await prefs.remove('selected_table_id');
  }

  void _startMusicPoller() {
    Timer.periodic(const Duration(seconds: 5), (timer) => refreshMusicStatus());
    refreshMusicStatus();
  }

  final Set<int> _deletedSongIds = {};

  void markSongDeleted(int songId) {
    _deletedSongIds.add(songId);
    final currentList = List<Map<String, dynamic>>.from(musicQueue.value);
    currentList.removeWhere(
      (qItem) => (int.tryParse(qItem['id']?.toString() ?? '0') ?? 0) == songId,
    );
    musicQueue.value = currentList;
  }

  final ValueNotifier<String> musicApiStatusMessage = ValueNotifier<String>(
    'Checking live queue...',
  );

  Future<void> refreshMusicStatus() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = (tenant != null && tenant.id.isNotEmpty)
        ? tenant.id
        : 'startups_main';

    final data = await ApiService.fetchMusicStatus(
      tenantId,
      userId: currentUserId,
    );

    if (data != null && data['status'] == 'success') {
      if (data['now_playing'] != null)
        currentSong.value = Map<String, dynamic>.from(data['now_playing']);
      if (data['queue'] != null && data['queue'] is List) {
        final serverQueue = List<Map<String, dynamic>>.from(data['queue']);
        final filteredQueue = serverQueue.where((item) {
          final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
          return !_deletedSongIds.contains(id);
        }).toList();

        musicQueue.value = filteredQueue;
        musicApiStatusMessage.value =
            "Connected to tenant '$tenantId'. DB returned ${filteredQueue.length} song request(s).";
        if (data['active_poll'] != null)
          activePoll.value = Map<String, dynamic>.from(data['active_poll']);
        else
          activePoll.value = null;
        return;
      }
    }

    // Fallback for Localhost / CORS / Offline Dev Mode
    musicApiStatusMessage.value =
        "Localhost Dev Mode (CORS / Offline Fallback Active)";

    // Default queue for Localhost dev testing
    if (musicQueue.value.isEmpty) {
      musicQueue.value =
          [
                {
                  'id': 1,
                  'tenant_id': tenantId,
                  'title': 'sd',
                  'artist': 'Requested',
                  'image':
                      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
                  'dedication': '23',
                  'requested_by': 'guest_1788758734781',
                  'votes': 12,
                  'status': 'queued',
                },
                {
                  'id': 2,
                  'tenant_id': tenantId,
                  'title': 'new aong',
                  'artist': 'Requested',
                  'image':
                      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
                  'dedication': null,
                  'requested_by': 'guest_1789468678124',
                  'votes': 4,
                  'status': 'queued',
                },
                {
                  'id': 3,
                  'tenant_id': tenantId,
                  'title': 'yuraj',
                  'artist': 'Requested',
                  'image':
                      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
                  'dedication': '72',
                  'requested_by': 'guest_1790320894536',
                  'votes': 0,
                  'status': 'queued',
                },
                {
                  'id': 4,
                  'tenant_id': tenantId,
                  'title': 'jh',
                  'artist': 'Requested',
                  'image':
                      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
                  'dedication': 'gh',
                  'requested_by': 'guest_1790330691637',
                  'votes': 1,
                  'status': 'queued',
                },
                {
                  'id': 5,
                  'tenant_id': tenantId,
                  'title': 'yyy',
                  'artist': 'Requested',
                  'image':
                      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
                  'dedication': '12',
                  'requested_by': 'guest_1790330691637',
                  'votes': 1,
                  'status': 'queued',
                },
              ]
              .where(
                (item) => !_deletedSongIds.contains(
                  int.tryParse(item['id']?.toString() ?? '0') ?? 0,
                ),
              )
              .toList();
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
    if (tenant == null || tenant.latitude == null || tenant.longitude == null)
      return;
    if (_lastOfferTime != null &&
        DateTime.now().difference(_lastOfferTime!).inHours < 12)
      return;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) return;
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      double dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        tenant.latitude!,
        tenant.longitude!,
      );
      if (dist <= 600) {
        _lastOfferTime = DateTime.now();
        isNearbyOfferVisible.value = true;
      }
    } catch (e) {}
  }

  final ValueNotifier<Map<String, String>?> latestIncomingPush =
      ValueNotifier<Map<String, String>?>(null);

  void _initPushListeners() {
    if (Firebase.apps.isEmpty) return;
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        refreshNotifications();
        refreshConversations();
        final title =
            message.notification?.title ??
            message.data['title'] ??
            'New Notification';
        final body =
            message.notification?.body ?? message.data['message'] ?? '';
        if (title.isNotEmpty || body.isNotEmpty) {
          latestIncomingPush.value = {'title': title, 'body': body};
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM foreground listener failed: $error');
      },
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        _handleOpenedPush(message);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM notification-open listener failed: $error');
      },
    );
    FirebaseMessaging.instance.getInitialMessage().then(
      (message) {
        if (message != null) _handleOpenedPush(message);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM initial notification lookup failed: $error');
      },
    );
    if (!kIsWeb) {
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) async {
          final tenant = TenantService().currentTenant.value;
          final userId = currentUserId;
          if (tenant != null && userId.isNotEmpty) {
            await ApiService.updateFcmToken(
              tenantId: tenant.id,
              userId: userId,
              token: token,
            );
          }

        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('FCM token refresh listener failed: $error');
        },
      );
    }
  }

  Future<void> _handleOpenedPush(RemoteMessage message) async {
    final notificationId =
        int.tryParse(message.data['notification_id']?.toString() ?? '');
    if (notificationId != null) {
      await acknowledgeNotification(notificationId);
    }
    await refreshNotifications();
    await refreshConversations();
  }

  Future<void> acknowledgeNotification(int notificationId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null ||
        customerSessionToken.isEmpty ||
        customerEmail.value.isEmpty) {
      return;
    }
    await ApiService.acknowledgeNotification(
      tenantId: tenant.id,
      userId: customerEmail.value,
      notificationId: notificationId,
      sessionToken: customerSessionToken,
    );
  }

  void _startNotificationsPoller() {
    Timer.periodic(
      const Duration(seconds: 15),
      (timer) => refreshNotifications(),
    );
  }

  int _lastUnseenCount = 0;
  final ValueNotifier<int> unseenNotificationsCount = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> notificationsList =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  Future<void> refreshNotifications() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return;
    final data = await ApiService.fetchNotifications(
      tenant.id,
      currentUserId,
      sessionToken: customerSessionToken,
    );
    if (data != null && data['status'] == 'success') {
      final newList = List<Map<String, dynamic>>.from(data['data'] ?? []);
      final newUnseen = (data['unseen_count'] ?? 0) as int;

      // Trigger top banner overlay on newly arrived notifications
      if (newUnseen > _lastUnseenCount && newList.isNotEmpty) {
        final topNotif = newList.first;
        latestIncomingPush.value = {
          'title': topNotif['title'] ?? 'New Notification',
          'body': topNotif['message'] ?? '',
        };
      }

      _lastUnseenCount = newUnseen;
      notificationsList.value = newList;
      unseenNotificationsCount.value = newUnseen;
    }
  }

  Future<void> clearNotificationBadge() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return;
    if (await ApiService.markNotificationsRead(
      tenant.id,
      currentUserId,
      sessionToken: customerSessionToken,
    )) {
      _lastUnseenCount = 0;
      unseenNotificationsCount.value = 0;
    }
  }

  void _startWavePoller() {
    Timer.periodic(const Duration(seconds: 12), (timer) async {
      final tenant = TenantService().currentTenant.value;
      if (tenant != null && currentUserId.isNotEmpty) {
        final waves = await ApiService.fetchWaves(tenant.id, currentUserId);
        if (waves != null && waves.isNotEmpty) {
          try {
            HapticFeedback.mediumImpact();
          } catch (_) {}

          final senderName = waves.first['user_name'] ?? 'Someone';
          latestIncomingPush.value = {
            'title': '👋 Digital Wave!',
            'body': '$senderName waved at you from their table!',
          };
        }
      }
    });
  }

  void _startPresenceCheckIn() {
    Timer.periodic(
      const Duration(seconds: 45),
      (timer) => updatePresenceOnServer(),
    );
  }

  Future<void> updatePresenceOnServer() async {
    final tenant = TenantService().currentTenant.value;
    final uid = currentUserId;

    if (tenant != null && uid.isNotEmpty) {
      // If table is not selected, we use 0 to indicate "Browsing/Near"
      int tableNum = selectedTableId.value ?? 0;

      debugPrint("NEARBY: Updating presence for $uid at Table $tableNum");
      await ApiService.updatePresence(
        tenantId: tenant.id,
        userId: uid,
        tableNumber: tableNum,
        userName: customerName.value.isNotEmpty ? customerName.value : null,
      );
      // Auto re-sync FCM Token for guest / email users
      setupPushNotifications();
    }
  }

  Future<void> updatePrivacyOnServer() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant != null && currentUserId.isNotEmpty) {
      await ApiService.updatePrivacySettings(
        tenantId: tenant.id,
        userId: currentUserId,
        isPublic: isProfileVisible.value,
        allowWaves: isWaveEnabled.value,
      );
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
    isWaitingForGoogleReview.value =
        prefs.getBool('is_waiting_for_google_review') ?? false;
    lastReviewText.value = prefs.getString('last_review_text');
    lastReviewId.value = prefs.getInt('last_review_id');
    hasConfirmedOrderAbove1000.value =
        prefs.getBool('has_confirmed_order_above_1000') ?? false;

    // LOAD PERSISTED GROUP SESSION
    final int? sid = prefs.getInt('active_session_id');
    if (sid != null) {
      final bool isHost = prefs.getBool('is_session_host') ?? false;
      final String? pin = prefs.getString('active_session_pin');
      startSessionPolling(sid, isHost, pin: pin);
    }

    // AUTO-RESTORE CUSTOMER SESSION (5-MINUTE TIMEOUT RULE)
    String? savedEmail = prefs.getString('customer_email');
    customerSessionToken = prefs.getString('customer_session_token') ?? '';
    bool isAuth = prefs.getBool('customer_authenticated') ?? false;
    int lastActive = prefs.getInt('last_active_time') ?? 0;
    int now = DateTime.now().millisecondsSinceEpoch;
    int elapsedMs = now - lastActive;
    const int fiveMinutesMs = 5 * 60 * 1000; // 5 minutes in milliseconds

    if (savedEmail != null &&
        savedEmail.isNotEmpty &&
        isAuth &&
        elapsedMs < fiveMinutesMs) {
      // User refreshed page within 5 minutes -> Auto restore session!
      customerEmail.value = savedEmail;
      isEmailSynced.value = true;
      needsPin.value = false;
      await prefs.setInt('last_active_time', now);

      // Fetch user profile & refresh exact points from database
      final res = await syncCustomerIdentity(savedEmail);
      if (res != null && res['user'] != null) {
        customerName.value = res['user']['name'] ?? 'Guest';
        userPoints.value =
            int.tryParse(res['user']['points']?.toString() ?? '0') ?? 0;
        orderStampCount.value =
            int.tryParse(res['user']['order_count']?.toString() ?? '0') ?? 0;
      }
      await refreshUserPoints();
    } else if (savedEmail != null && savedEmail.isNotEmpty) {
      // Session expired (> 5 minutes) or unauthenticated
      customerEmail.value = savedEmail;
      isEmailSynced.value = false;
      needsPin.value = false;
      userPoints.value = 0;
      orderStampCount.value = 0;
    } else {
      isEmailSynced.value = false;
      needsPin.value = false;
      userPoints.value = 0;
      orderStampCount.value = 0;
    }

    String? gId = prefs.getString('guest_id');
    if (gId == null || gId.trim().isEmpty || gId.toLowerCase() == 'guest') {
      gId =
          'guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
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
    await fetchReviews(); // Fetch reviews on load
    checkNotificationPermission();
  }

  Future<void> _persistOrder(int id, {bool isRemove = false}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> current = prefs.getStringList('active_order_ids') ?? [];
    if (isRemove)
      current.remove(id.toString());
    else if (!current.contains(id.toString()))
      current.add(id.toString());
    await prefs.setStringList('active_order_ids', current);
    activeOrderIds.value = current.map((e) => int.parse(e)).toList();
  }

  void _startGlobalTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (tableCountdownTimers.value.isNotEmpty) {
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
  final ValueNotifier<List<CartItem>> placedOrderItems =
      ValueNotifier<List<CartItem>>([]);
  final ValueNotifier<int> currentTabIndex = ValueNotifier<int>(0);
  final ValueNotifier<bool> isQrLaunch = ValueNotifier<bool>(false);
  final ValueNotifier<int?> selectedTableId = ValueNotifier<int?>(null);
  final ValueNotifier<String> guestId = ValueNotifier<String>('');
  final ValueNotifier<String> customerEmail = ValueNotifier<String>('');
  String customerSessionToken = '';
  final ValueNotifier<String> customerName = ValueNotifier<String>('');
  final ValueNotifier<bool> needsPin = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isEmailSynced = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isNewToShop = ValueNotifier<bool>(false);
  final ValueNotifier<String> userGender = ValueNotifier<String>('Male');
  final ValueNotifier<bool> isProfileVisible = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isWaveEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isOnboardingComplete = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showNotificationPrompt = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isConnectedToRestaurantWiFi = ValueNotifier<bool>(
    true,
  );
  final ValueNotifier<bool> isOrderPaid = ValueNotifier<bool>(false);

  // --- REVIEW SYSTEM ---
  final ValueNotifier<bool> isWaitingForGoogleReview = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<String?> lastReviewText = ValueNotifier<String?>(null);
  final ValueNotifier<int?> lastReviewId = ValueNotifier<int?>(null);

  Future<void> submitLocalReview(
    String text,
    int rating, {
    int? reviewId,
  }) async {
    lastReviewText.value = text;
    lastReviewId.value = reviewId;
    isWaitingForGoogleReview.value = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_waiting_for_google_review', true);
    await prefs.setString('last_review_text', text);
    if (reviewId != null) await prefs.setInt('last_review_id', reviewId);
  }

  Future<void> clearReviewFlag() async {
    isWaitingForGoogleReview.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_waiting_for_google_review');
    await prefs.remove('last_review_id');
  }

  Future<void> verifyReviewSuccess() async {
    if (lastReviewId.value != null) {
      await ApiService.verifyReviewOnServer(lastReviewId.value!);
    }
    await clearReviewFlag();
  }

  String ensureGuestId() {
    if (guestId.value.isEmpty || guestId.value.toLowerCase() == 'guest') {
      final newGid =
          'guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      guestId.value = newGid;
      SharedPreferences.getInstance().then(
        (p) => p.setString('guest_id', newGid),
      );
    }
    return guestId.value;
  }

  String get currentUserId {
    final staff = TenantService().currentStaff.value;
    if (staff != null) return staff.id.toString();
    if (customerEmail.value.isNotEmpty) return customerEmail.value;
    return ensureGuestId();
  }

  final ValueNotifier<List<int>> activeOrderIds = ValueNotifier<List<int>>([]);
  final ValueNotifier<int?> activeOrderId = ValueNotifier<int?>(null);
  final ValueNotifier<String?> activeCategory = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isOrderActive = ValueNotifier<bool>(false);
  final ValueNotifier<OrderStatus> orderStatus = ValueNotifier<OrderStatus>(
    OrderStatus.pending,
  );
  final ValueNotifier<Duration> totalGameTime = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<int> totalOrdersCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> hasConfirmedOrderAbove1000 = ValueNotifier<bool>(
    false,
  );

  Future<void> _checkAndSetQualifiedOrder(double totalAmount) async {
    if (totalAmount >= 1000) {
      hasConfirmedOrderAbove1000.value = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_confirmed_order_above_1000', true);
    }
  }

  final ValueNotifier<int> followersCount = ValueNotifier<int>(0);
  final ValueNotifier<int> followingCount = ValueNotifier<int>(0);
  final ValueNotifier<int> connectionsCount = ValueNotifier<int>(0);

  // --- SOCIAL METHODS ---
  Future<bool> toggleFollow(String targetId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant != null &&
        currentUserId.isNotEmpty &&
        currentUserId != targetId) {
      if ((await ApiService.toggleFollow(
            tenantId: tenant.id,
            myId: currentUserId,
            targetId: targetId,
          ))['success'] ==
          true) {
        await ApiService.deliverPendingChatMessages(
          tenantId: tenant.id,
          userId: currentUserId,
          otherUserId: targetId,
        );
        await refreshSocialStats();
        await fetchSocialLists();
        await refreshConversations();
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

  final ValueNotifier<List<Map<String, dynamic>>> followingList = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Map<String, dynamic>>> requestsList = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Map<String, dynamic>>> friendsList = ValueNotifier(
    [],
  );

  Future<void> fetchSocialLists() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return;
    final following = await ApiService.fetchSocialList(
      action: 'get_following',
      tenantId: tenant.id,
      userId: currentUserId,
    );
    final requests = await ApiService.fetchSocialList(
      action: 'get_requests',
      tenantId: tenant.id,
      userId: currentUserId,
    );
    final friends = await ApiService.fetchSocialList(
      action: 'get_friends',
      tenantId: tenant.id,
      userId: currentUserId,
    );
    if (following != null)
      followingList.value = List<Map<String, dynamic>>.from(following);
    if (requests != null)
      requestsList.value = List<Map<String, dynamic>>.from(requests);
    if (friends != null)
      friendsList.value = List<Map<String, dynamic>>.from(friends);
    final orderData = await ApiService.fetchUserOrders(
      tenant.id,
      currentUserId,
    );
    if (orderData != null) {
      totalOrdersCount.value = orderData['total_count'] ?? 0;
      double maxAmt =
          double.tryParse(orderData['max_amount']?.toString() ?? '0') ?? 0;
      if (maxAmt >= 1000) _checkAndSetQualifiedOrder(maxAmt);
    }
  }

  // --- REVIEWS ---
  final ValueNotifier<List<Map<String, dynamic>>> activeReviews = ValueNotifier(
    [],
  );
  final ValueNotifier<double> averageRating = ValueNotifier(0.0);
  final ValueNotifier<int> totalReviewsCount = ValueNotifier(0);
  final ValueNotifier<Map<int, double>> ratingDistribution = ValueNotifier({});

  Future<void> fetchReviews({String? targetUserId}) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final data = await ApiService.fetchReviews(
      tenant.id,
      targetUserId: targetUserId,
    );
    if (data != null) {
      activeReviews.value = data;
      _calculateReviewStats(data);
    }
  }

  void _calculateReviewStats(List<Map<String, dynamic>> reviews) {
    if (reviews.isEmpty) {
      averageRating.value = 0.0;
      totalReviewsCount.value = 0;
      ratingDistribution.value = {};
      return;
    }

    double total = 0;
    Map<int, int> counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    for (var r in reviews) {
      int rating = int.tryParse(r['rating']?.toString() ?? '0') ?? 0;
      total += rating;
      if (counts.containsKey(rating)) {
        counts[rating] = (counts[rating] ?? 0) + 1;
      }
    }

    averageRating.value = total / reviews.length;
    totalReviewsCount.value = reviews.length;

    Map<int, double> distribution = {};
    for (int i = 1; i <= 5; i++) {
      distribution[i] = reviews.isEmpty ? 0.0 : (counts[i]! / reviews.length);
    }
    ratingDistribution.value = distribution;
  }

  Future<bool> postReview(String text, int rating) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) {
      debugPrint("REVIEW: Missing Tenant or User ID");
      return false;
    }

    final res = await ApiService.submitReview({
      "tenant_id": tenant.id,
      "user_id": currentUserId,
      "user_name": customerName.value.isNotEmpty ? customerName.value : "Diner",
      "user_image": userGender.value == 'Female'
          ? 'https://randomuser.me/api/portraits/women/44.jpg'
          : 'https://randomuser.me/api/portraits/men/32.jpg',
      "rating": rating,
      "review": text,
    });

    if (res['status'] == 'success') {
      await fetchReviews();
      return true;
    } else {
      debugPrint("REVIEW ERROR: ${res['message'] ?? 'Unknown Server Error'}");
      return false;
    }
  }

  Future<bool> deleteReview(int reviewId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return false;

    if (await ApiService.deleteReview(tenant.id, reviewId, currentUserId)) {
      await fetchReviews();
      return true;
    }
    return false;
  }

  // --- LOYALTY ---
  final ValueNotifier<int> userPoints = ValueNotifier<int>(0);
  final ValueNotifier<int> orderStampCount = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, dynamic>?> loyaltySettings =
      ValueNotifier<Map<String, dynamic>?>(null);

  Future<void> fetchLoyaltySettings() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final settings = await ApiService.fetchLoyaltySettings(tenant.id);
    if (settings != null) loyaltySettings.value = settings;
  }

  Future<void> refreshUserPoints() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    // Strict Unauthenticated Guard: Guest profiles cannot query global points
    if (!isEmailSynced.value || customerEmail.value.isEmpty) {
      userPoints.value = 0;
      orderStampCount.value = 0;
      return;
    }

    final uid = customerEmail.value.trim().toLowerCase();

    final response = await http.get(
      Uri.parse(
        "${ApiService.baseUrl}/loyalty_api.php?action=get_points&user_id=${Uri.encodeComponent(uid)}&tenant_id=${tenant.id}",
      ),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        final String respUid = (data['user_id'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (respUid.isEmpty || respUid == uid) {
          userPoints.value =
              int.tryParse(data['points']?.toString() ?? '0') ?? 0;
          orderStampCount.value =
              int.tryParse(data['order_count']?.toString() ?? '0') ?? 0;
        }
      }
    }
  }

  // --- MUSIC ---
  final ValueNotifier<List<Map<String, dynamic>>> musicQueue =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<Map<String, dynamic>>
  currentSong = ValueNotifier<Map<String, dynamic>>({
    'title': 'No Song Playing',
    'artist': '-',
    'image':
        'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
    'progress': 0.0,
  });
  final ValueNotifier<int> vibeScore = ValueNotifier<int>(50);
  final ValueNotifier<Map<String, dynamic>?> activePoll =
      ValueNotifier<Map<String, dynamic>?>(null);

  Future<Map<String, dynamic>> toggleMusicVote(int songId) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = (tenant != null && tenant.id.isNotEmpty)
        ? tenant.id
        : 'startups_main';

    // Optimistically update local vote count for instant feedback
    final currentList = List<Map<String, dynamic>>.from(musicQueue.value);
    final index = currentList.indexWhere(
      (item) => (int.tryParse(item['id']?.toString() ?? '0') ?? 0) == songId,
    );
    if (index != -1) {
      final item = Map<String, dynamic>.from(currentList[index]);
      final bool currentlyLiked = item['user_liked'] == true;
      final int currentVotes =
          int.tryParse(item['votes']?.toString() ?? '0') ?? 0;

      item['user_liked'] = !currentlyLiked;
      item['votes'] = currentlyLiked
          ? (currentVotes - 1).clamp(0, 9999)
          : currentVotes + 1;
      currentList[index] = item;
      musicQueue.value = currentList;
    }

    final result = await ApiService.voteSong(
      tenantId: tenantId,
      userId: currentUserId,
      songId: songId,
    );
    if (result['status'] == 'success') {
      await refreshMusicStatus();
      vibeScore.value = (vibeScore.value + 2).clamp(0, 100);
      return {"success": true};
    }
    return {"success": false};
  }

  Future<Map<String, dynamic>> requestSong(
    String title,
    String artist,
    String? dedication,
  ) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = (tenant != null && tenant.id.isNotEmpty)
        ? tenant.id
        : 'startups_main';

    final result = await ApiService.requestMusic({
      'tenant_id': tenantId,
      'title': title,
      'artist': artist,
      'dedication': dedication,
      'user_id': currentUserId,
    });
    if (result['success'] == true) {
      await refreshMusicStatus();
      vibeScore.value = (vibeScore.value + 5).clamp(0, 100);
    }
    return result;
  }

  void createMusicPoll(String title, List<Map<String, dynamic>> songs) {
    activePoll.value = {
      'title': title,
      'options': songs.map((s) => {...s, 'votes': 0}).toList(),
      'endTime': DateTime.now().add(const Duration(minutes: 5)),
      'userVotedIndex': -1,
      'totalVotes': 0,
    };
  }

  void castPollVote(int optionIndex) {
    if (activePoll.value == null || activePoll.value!['userVotedIndex'] != -1)
      return;
    Map<String, dynamic> poll = Map.from(activePoll.value!);
    List<dynamic> opts = List.from(poll['options']);
    opts[optionIndex]['votes'] += 1;
    poll['options'] = opts;
    poll['totalVotes'] += 1;
    poll['userVotedIndex'] = optionIndex;
    activePoll.value = poll;
  }

  // --- TABLES & ORDERS ---
  final ValueNotifier<Map<int, List<CartItem>>> tableOrders = ValueNotifier({});
  final ValueNotifier<Map<int, List<CartItem>>> confirmedTableOrders =
      ValueNotifier({});
  final ValueNotifier<Map<int, String>> tableStatuses = ValueNotifier({});
  final ValueNotifier<Map<int, String>> tableKitchenStages = ValueNotifier({});
  final ValueNotifier<Map<int, bool>> tableReadyNotifications = ValueNotifier(
    {},
  );
  final ValueNotifier<Map<int, DateTime>> tableStartTimes = ValueNotifier({});
  final ValueNotifier<Map<int, int>> tableCountdownTimers = ValueNotifier({});
  final ValueNotifier<Map<int, int>> tableOriginalDurations = ValueNotifier({});

  void initializeTables(int count) {
    if (tableStatuses.value.isEmpty) {
      Map<int, String> initial = {};
      for (int i = 1; i <= count; i++) initial[i] = "Available";
      tableStatuses.value = initial;
    }
  }

  void updateTableStatus(int tableId, String status) {
    tableStatuses.value = Map.from(tableStatuses.value)..[tableId] = status;
  }

  void settleTable(int tableId) {
    updateTableStatus(tableId, "Available");
    tableOrders.value = Map.from(tableOrders.value)..remove(tableId);
    confirmedTableOrders.value = Map.from(confirmedTableOrders.value)
      ..remove(tableId);
  }

  void clearTable(int tableId) => settleTable(tableId);
  void addOrderToTable(int tableId, List<CartItem> newItems) {
    Map<int, List<CartItem>> orders = Map.from(tableOrders.value);
    List<CartItem> existing = List.from(orders[tableId] ?? []);
    for (var newItem in newItems) {
      int idx = existing.indexWhere(
        (i) => i.product.title == newItem.product.title,
      );
      if (idx != -1)
        existing[idx].quantity += newItem.quantity;
      else
        existing.add(newItem);
    }
    orders[tableId] = existing;
    tableOrders.value = orders;
    updateTableStatus(tableId, "Dining");
  }

  void removeFromTableOrder(int tableId, String title) {
    Map<int, List<CartItem>> orders = Map.from(tableOrders.value);
    List<CartItem> existing = List.from(orders[tableId] ?? []);
    existing.removeWhere((i) => i.product.title == title);
    if (existing.isEmpty)
      settleTable(tableId);
    else {
      orders[tableId] = existing;
      tableOrders.value = orders;
    }
  }

  Future<Map<String, dynamic>> confirmTableOrderWithResult(int tableId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return {"success": false};
    final List<CartItem> newItems = tableOrders.value[tableId] ?? [];
    double total = 0;
    List<Map<String, dynamic>> itemsJson = [];
    for (var item in newItems) {
      double prc =
          double.tryParse(
            item.product.price.replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          0;
      total += prc * item.quantity;
      itemsJson.add({
        "name": item.product.title,
        "quantity": item.quantity,
        "price": prc,
      });
    }
    final result = await ApiService.placeTableOrder({
      "tenant_id": tenant.id,
      "table_number": tableId,
      "user_id": currentUserId,
      "total_amount": total,
      "items": itemsJson,
    });
    if (result != null && result['status'] == 'success') {
      _checkAndSetQualifiedOrder(total);
      final Map<int, List<CartItem>> updated = Map.from(
        confirmedTableOrders.value,
      );
      updated[tableId] = (updated[tableId] ?? [])..addAll(newItems);
      confirmedTableOrders.value = updated;
      tableOrders.value = Map.from(tableOrders.value)..remove(tableId);
      return {"success": true};
    }
    return {"success": false};
  }

  static int parseTableId(String str) =>
      int.tryParse(str.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  void clearWaiterNotification(int id) =>
      tableReadyNotifications.value = Map.from(tableReadyNotifications.value)
        ..remove(id);

  // --- IDENTITY ---
  Future<Map<String, dynamic>?> syncCustomerIdentity(
    String email, {
    String? name,
  }) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return null;
    final res = await ApiService.syncCustomerProfile(
      tenantId: tenant.id,
      email: email,
      name: name,
    );
    if (res != null && res['status'] == 'success') {
      final bool hasPin =
          (res['has_pin'] == true) || (res['needs_pin'] == false);
      if (!hasPin) {
        isNewToShop.value = res['is_new_to_shop'] == true;
        needsPin.value = true;
      }
      return res;
    }
    return null;
  }

  Future<Map<String, dynamic>> verifyAndLoginPin(
    String email,
    String pin,
    Map<String, dynamic> userMap,
  ) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      return {"status": "error", "message": "No restaurant selected"};
    }
    final res = await ApiService.verifyCustomerPin(
      tenantId: tenant.id,
      email: email,
      pin: pin,
    );
    if (res['status'] == 'success') {
      // Clear previous user points immediately before switching to avoid coin leakage
      userPoints.value = 0;
      orderStampCount.value = 0;

      customerEmail.value = email;
      customerName.value = userMap['name'] ?? 'Guest';
      needsPin.value = false;
      isEmailSynced.value = true;
      userPoints.value = userMap['points'] ?? 0;
      orderStampCount.value = userMap['order_count'] ?? 0;
      isProfileVisible.value =
          (userMap['is_public'] == 1 || userMap['is_public'] == true);
      isWaveEnabled.value =
          (userMap['allow_waves'] == 1 || userMap['allow_waves'] == true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_email', email);
      customerSessionToken = (res['session_token'] ?? '').toString();
      if (customerSessionToken.isNotEmpty) {
        await prefs.setString('customer_session_token', customerSessionToken);
      } else {
        await prefs.remove('customer_session_token');
      }
      await prefs.setBool('customer_authenticated', true);
      await prefs.setInt(
        'last_active_time',
        DateTime.now().millisecondsSinceEpoch,
      );
      await refreshUserPoints();
      await fetchSocialLists();
    }
    return res;
  }

  Future<bool> registerAndSetPin(
    String email,
    String pin,
    Map<String, dynamic> userMap,
  ) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return false;
    final saveResult = await ApiService.saveCustomerPin(
      tenantId: tenant.id,
      email: email,
      pin: pin,
    );
    if (saveResult['status'] == 'success') {
      // Clear previous user points immediately before setting new user
      userPoints.value = 0;
      orderStampCount.value = 0;

      customerEmail.value = email;
      customerName.value = userMap['name'] ?? 'Guest';
      needsPin.value = false;
      isEmailSynced.value = true;
      userPoints.value = userMap['points'] ?? 0;
      orderStampCount.value = userMap['order_count'] ?? 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_email', email);
      customerSessionToken = (saveResult['session_token'] ?? '').toString();
      if (customerSessionToken.isNotEmpty) {
        await prefs.setString('customer_session_token', customerSessionToken);
      } else {
        await prefs.remove('customer_session_token');
      }
      await prefs.setBool('customer_authenticated', true);
      await prefs.setInt(
        'last_active_time',
        DateTime.now().millisecondsSinceEpoch,
      );
      await refreshUserPoints();
      await fetchSocialLists();
      return true;
    }
    return false;
  }

  Future<bool> finalizeSecurityPin(String pin) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || customerEmail.value.isEmpty) return false;
    final saveResult = await ApiService.saveCustomerPin(
      tenantId: tenant.id,
      email: customerEmail.value,
      pin: pin,
    );
    if (saveResult['status'] == 'success') {
      needsPin.value = false;
      isEmailSynced.value = true;
      final prefs = await SharedPreferences.getInstance();
      customerSessionToken = (saveResult['session_token'] ?? '').toString();
      if (customerSessionToken.isNotEmpty) {
        await prefs.setString('customer_session_token', customerSessionToken);
      } else {
        await prefs.remove('customer_session_token');
      }
      await prefs.setBool('customer_authenticated', true);
      await prefs.setInt(
        'last_active_time',
        DateTime.now().millisecondsSinceEpoch,
      );
      await fetchSocialLists();
      return true;
    }
    return false;
  }

  Future<void> touchUserSession() async {
    if (customerEmail.value.isNotEmpty && isEmailSynced.value) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_active_time',
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  Future<void> logoutCustomer() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant != null && customerSessionToken.isNotEmpty) {
      await ApiService.revokeCustomerSession(
        tenantId: tenant.id,
        sessionToken: customerSessionToken,
      );
    }
    customerEmail.value = '';
    customerSessionToken = '';
    customerName.value = 'Guest';
    isEmailSynced.value = false;
    needsPin.value = false;
    userPoints.value = 0;
    orderStampCount.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_email');
    await prefs.remove('customer_session_token');
    await prefs.remove('customer_authenticated');
    await prefs.remove('last_active_time');
  }

  Future<bool> updateProfile({
    required String name,
    required String gender,
    bool isAnon = false,
  }) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return false;
    if (await ApiService.submitOnboarding(
      tenantId: tenant.id,
      userId: currentUserId,
      name: name,
      gender: gender,
      isAnonymous: isAnon,
    )) {
      customerName.value = name;
      userGender.value = gender;
      isOnboardingComplete.value = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await refreshSocialStats();
      await fetchSocialLists();
      await setupPushNotifications();
      return true;
    }
    return false;
  }

  Future<void> checkNotificationPermission() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _registerPushToken(messaging);
      } else if (settings.authorizationStatus ==
              AuthorizationStatus.notDetermined &&
          prefs.getBool('notif_prompt_dismissed') != true) {
        showNotificationPrompt.value = true;
      }
    } catch (e, stackTrace) {
      debugPrint('Notification permission check failed: $e\n$stackTrace');
    }
  }

  Future<bool> setupPushNotifications() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return false;
    try {
      if (Firebase.apps.isEmpty) return false;
      final messaging = FirebaseMessaging.instance;
      var settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint(
          'Push notifications are not authorized: ${settings.authorizationStatus}',
        );
        return false;
      }
      final registered = await _registerPushToken(messaging);
      if (registered) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notif_prompt_dismissed', true);
      }
      return registered;
    } catch (e, stackTrace) {
      debugPrint('Push notification setup failed: $e\n$stackTrace');
      return false;
    }
  }

  Future<bool> _registerPushToken(FirebaseMessaging messaging) async {
    final tenant = TenantService().currentTenant.value;
    final userId = currentUserId;
    if (tenant == null || userId.isEmpty) return false;

    if (kIsWeb) await registerPushServiceWorker();
    final token = await (kIsWeb
        ? messaging.getToken(
            vapidKey:
                'BGfucW_HKKPEUrswHLq1S-WGdeyHv6jTkSGvsJ_bP20OelPwEpMcsxAkhpf34iK3g-H1E8NVVY8Vo96bIyxagQg',
          )
        : messaging.getToken());
    if (token == null || token.isEmpty) {
      debugPrint('FCM did not return a registration token.');
      return false;
    }
    final saved = await ApiService.updateFcmToken(
      tenantId: tenant.id,
      userId: userId,
      token: token,
    );
    if (!saved) debugPrint('Server did not save the FCM registration token.');
    return saved;
  }

  Future<void> checkOrRequestNotificationOnAction() async {
    try {
      if (Firebase.apps.isEmpty) return;
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('notif_prompt_dismissed');
        showNotificationPrompt.value = true;
      }
    } catch (e, stackTrace) {
      debugPrint('Notification action check failed: $e\n$stackTrace');
    }
  }

  Future<void> syncProcurementData(String tenantId) async {
    final supData = await ApiService.fetchSuppliers(tenantId);
    final purData = await ApiService.fetchPurchases(tenantId);
    if (supData != null)
      allSuppliers.value = List<Map<String, dynamic>>.from(supData);
    if (purData != null)
      allPurchases.value = List<Map<String, dynamic>>.from(purData);
  }

  final ValueNotifier<List<Map<String, dynamic>>> allPurchases = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Map<String, dynamic>>> allSuppliers = ValueNotifier(
    [],
  );

  // --- OTHERS ---
  final ValueNotifier<bool> onlyMutualChat = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showTableNumber = ValueNotifier<bool>(true);
  final ValueNotifier<bool> socialVibration = ValueNotifier<bool>(true);
  final ValueNotifier<bool> autoWaveBack = ValueNotifier<bool>(false);
  bool isMysteryBoxTime() {
    final h = DateTime.now().hour;
    return h >= 8 && h < 22;
  }

  int getItemQuantity(String title) {
    final idx = items.value.indexWhere((i) => i.product.title == title);
    return idx != -1 ? items.value[idx].quantity : 0;
  }

  void pushToCart({required Product product, required int quantity}) {
    List<CartItem> curr = List.from(items.value);
    int idx = curr.indexWhere((i) => i.product.title == product.title);
    if (idx != -1)
      curr[idx].quantity += quantity;
    else
      curr.add(CartItem(product: product, quantity: quantity));
    items.value = curr;
  }

  void removeFromCart(Product p) {
    items.value = List<CartItem>.from(items.value)
      ..removeWhere((i) => i.product.title == p.title);
  }

  void updateQuantity(Product p, int qty) {
    if (qty <= 0)
      removeFromCart(p);
    else {
      List<CartItem> curr = List.from(items.value);
      int idx = curr.indexWhere((i) => i.product.title == p.title);
      if (idx != -1) {
        curr[idx].quantity = qty;
        items.value = curr;
      }
    }
  }

  void clearCart() => items.value = [];
  void navigateToCategory(String? c) {
    activeCategory.value = c;
    currentTabIndex.value = 1;
  }

  void switchTable(int id) => selectedTableId.value = id;
  int get cartCount {
    int count = 0;
    for (var item in items.value) count += item.quantity;
    return count;
  }

  double get totalPrice {
    double total = 0;
    for (var item in items.value) {
      String prcStr = item.product.price
          .replaceAll('NPR ', '')
          .replaceAll(',', '');
      total += (double.tryParse(prcStr) ?? 0) * item.quantity;
    }
    return total;
  }

  final ValueNotifier<List<Map<String, dynamic>>> allHistoricalBills =
      ValueNotifier([]);
  final ValueNotifier<Map<String, dynamic>> inventoryStock = ValueNotifier({});
  final ValueNotifier<List<Map<String, dynamic>>> staffDirectory =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> departmentsList =
      ValueNotifier([]);

  Future<void> fetchCentralDepartments([String? tid]) async {
    final tenant = TenantService().currentTenant.value;
    final id = tid ?? tenant?.id ?? 'startups_main';
    final data = await ApiService.fetchDepartments(id);
    if (data != null)
      departmentsList.value = List<Map<String, dynamic>>.from(data);
  }

  ValueNotifier<int> get waiterTabIndex => waiterTabIndexNotifier;
  final ValueNotifier<Map<int, Map<String, CartItem>>> pendingTableOrders =
      ValueNotifier({});
  ValueNotifier<int?> get activeStaffTableId => activeStaffTableIdNotifier;

  ValueNotifier<bool> get isMysteryBoxOpened => isMysteryBoxOpenedNotifier;
  ValueNotifier<bool> get isRewardClaimed => isRewardClaimedNotifier;
  final ValueNotifier<List<Map<String, dynamic>>> previousWins = ValueNotifier(
    [],
  );

  void setPendingItem(int tableId, Map<String, dynamic> p, int qty) {
    Map<int, Map<String, CartItem>> all = Map.from(pendingTableOrders.value);
    Map<String, CartItem> table = Map.from(all[tableId] ?? {});
    String title = p['title'];
    if (qty <= 0)
      table.remove(title);
    else
      table[title] = CartItem(
        product: Product(
          title: p['title'],
          price: p['price'].toString(),
          image: p['image'] ?? '',
          tag: p['tag'] ?? "Staff",
          rating: p['rating'] ?? "N/A",
        ),
        quantity: qty,
      );
    all[tableId] = table;
    pendingTableOrders.value = all;
  }

  void clearPendingOrder(int id) =>
      pendingTableOrders.value = Map.from(pendingTableOrders.value)..remove(id);

  Future<void> placeOrder() async {
    if (items.value.isEmpty || selectedTableId.value == null) return;
    double total = totalPrice;
    final itemsJson = items.value
        .map(
          (i) => {
            "name": i.product.title,
            "quantity": i.quantity,
            "price":
                double.tryParse(
                  i.product.price.replaceAll(RegExp(r'[^0-9.]'), ''),
                ) ??
                0,
          },
        )
        .toList();
    final result = await ApiService.placeTableOrder({
      "tenant_id": TenantService().currentTenant.value!.id,
      "table_number": selectedTableId.value,
      "user_id": currentUserId,
      "customer_email": customerEmail.value,
      "total_amount": total,
      "items": itemsJson,
    });
    if (result != null && result['status'] == 'success') {
      _checkAndSetQualifiedOrder(total);
      int id = int.parse(result['order_id'].toString());
      activeOrderId.value = id;

      // AUTO-SYNC TO LIVE SESSION
      final List<Map<String, dynamic>> sessionUpdate = items.value
          .map(
            (i) => {
              'title': i.product.title,
              'who': customerName.value.isNotEmpty
                  ? customerName.value
                  : "Host",
              'status': 'Kitchen',
              'price': i.product.price,
              'image': i.product.image,
            },
          )
          .toList();
      liveSessionOrders.value = List.from(liveSessionOrders.value)
        ..addAll(sessionUpdate);

      await _persistOrder(id);
      clearCart();
      isOrderActive.value = true;
      _startStatusSync();
    }
  }

  void _startStatusSync() {
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (activeOrderId.value == null) {
        timer.cancel();
        return;
      }
      final live = await ApiService.fetchOrderStatus(activeOrderId.value!);
      if (live != null) {
        if (live == 'Pending')
          orderStatus.value = OrderStatus.pending;
        else if (live == 'Approved')
          orderStatus.value = OrderStatus.approved;
        else if (live == 'Preparing')
          orderStatus.value = OrderStatus.preparing;
        else if (live == 'Ready')
          orderStatus.value = OrderStatus.ready;
        else if (live == 'Completed') {
          isOrderActive.value = false;
          timer.cancel();
        }
      }
    });
  }

  void _mapStatus(String dbStatus) {
    if (dbStatus == 'Pending')
      orderStatus.value = OrderStatus.pending;
    else if (dbStatus == 'Approved')
      orderStatus.value = OrderStatus.approved;
    else if (dbStatus == 'Preparing')
      orderStatus.value = OrderStatus.preparing;
    else if (dbStatus == 'Ready')
      orderStatus.value = OrderStatus.ready;
  }

  Future<void> clearActiveOrder() async {
    isOrderActive.value = false;
    activeOrderId.value = null;
    placedOrderItems.value = [];
    orderStatus.value = OrderStatus.pending;
  }

  // --- GAMIFICATION ---
  final ValueNotifier<int> tapWarTimer = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> tapLeaderboard =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  void startTapWar() {
    tapWarTimer.value = 30;
    tapLeaderboard.value = [
      {'table': 'Your Table', 'score': 0, 'isUser': true},
    ];
  }

  void recordTap() {
    if (tapWarTimer.value > 0) {
      List<Map<String, dynamic>> curr = List.from(tapLeaderboard.value);
      curr[0]['score']++;
      tapLeaderboard.value = curr;
    }
  }

  void endTapWar() {
    tapWarTimer.value = 0;
  }

  void updateTableName(String old, String newN) {
    List<Map<String, dynamic>> curr = List.from(tapLeaderboard.value);
    for (var i in curr) if (i['table'] == old) i['table'] = newN;
    tapLeaderboard.value = curr;
  }

  void addGameTime(Duration d) {
    totalGameTime.value += d;
  }

  Future<Map<String, dynamic>> addPoints(
    String tenantId,
    String userId, {
    double orderAmount = 0,
    int points = 0,
    int incrementStamps = 0,
  }) async {
    final result = await ApiService.addPoints(
      tenantId,
      userId,
      orderAmount: orderAmount,
      points: points,
      incrementStamps: incrementStamps,
    );
    await refreshUserPoints();
    return result;
  }

  // --- GROUP DINING LIVE SYNC (V3 - Real Backend) ---
  final ValueNotifier<List<Map<String, dynamic>>> liveSessionOrders =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> liveSessionMembers =
      ValueNotifier([]);
  final ValueNotifier<double> liveSessionTotal = ValueNotifier(0.0);
  final ValueNotifier<bool> isSessionHost = ValueNotifier(false);
  final ValueNotifier<int?> activeSessionId = ValueNotifier(null);
  final ValueNotifier<String?> activeSessionPin = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isSessionLocked = ValueNotifier(false);
  final ValueNotifier<String?> activeSessionQr = ValueNotifier<String?>(null);
  final ValueNotifier<bool> openTablePickerTrigger = ValueNotifier(false);
  final ValueNotifier<bool> isSplitShared = ValueNotifier(false);
  final ValueNotifier<String?> volunteerId = ValueNotifier<String?>(null);

  Timer? _sessionPoller;
  String? _lastSyncTime;
  int _failedSyncCount = 0;

  void startSessionPolling(int sid, bool asHost, {String? pin}) async {
    if (pin != null) activeSessionPin.value = pin;
    activeSessionId.value = sid;
    isSessionHost.value = asHost;

    _lastSyncTime = null;
    _failedSyncCount = 0;
    _sessionPoller?.cancel();
    _sessionPoller = Timer.periodic(
      const Duration(seconds: 8),
      (timer) => syncSessionData(),
    );
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
      lastSyncTime: _lastSyncTime,
    );

    if (result != null) {
      _failedSyncCount = 0;
      if (result['status'] == 'success') {
        final data = result['data'];
        liveSessionOrders.value = List<Map<String, dynamic>>.from(
          data['items'] ?? [],
        );
        liveSessionMembers.value = List<Map<String, dynamic>>.from(
          data['members'] ?? [],
        );
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
      } else {
        resetSession();
      }
    } else {
      _failedSyncCount++;
      if (_failedSyncCount >= 2) {
        resetSession();
      }
    }
  }

  final ValueNotifier<bool> showPaymentPopup = ValueNotifier(false);

  void resetSession() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant != null && currentUserId.isNotEmpty) {
      ApiService.goOffline(tenantId: tenant.id, userId: currentUserId);
    }

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
  void addMembersToGroup(List<Map<String, dynamic>> m) {
    currentGroupMembers.addAll(m);
  }
}

final storeManager = ShopManager();
final ValueNotifier<bool> isMysteryBoxOpenedNotifier = ValueNotifier(false);
final ValueNotifier<bool> isRewardClaimedNotifier = ValueNotifier(false);
final ValueNotifier<int> waiterTabIndexNotifier = ValueNotifier(0);
final ValueNotifier<int?> activeStaffTableIdNotifier = ValueNotifier(null);
