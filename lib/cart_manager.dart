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

enum NotificationPermissionResult { enabled, emailEnabled }

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

class ShopManager with WidgetsBindingObserver {
  static final ShopManager instance = ShopManager._internal();
  factory ShopManager() => instance;

  Future<void>? _initFuture;
  Timer? _orderStatusTimer;
  Timer? _musicTimer;
  Timer? _notificationsTimer;
  Timer? _waveTimer;
  Timer? _presenceTimer;
  bool _isAppInForeground = true;
  String? _lastRegisteredFcmToken;
  String? _lastRegisteredFcmKey;
  String? _lastPresenceTenantId;
  String? _lastPresenceUserId;
  String? _presencePausedTenantId;
  String? _orderTenantId;
  String? _customerTenantId;

  Future<void> ensureInitialized() async {
    _initFuture ??= _loadPersistedOrder();
    await _initFuture;
  }

  ShopManager._internal() {
    WidgetsBinding.instance.addObserver(this);
    _orderTenantId = TenantService().currentTenant.value?.id.trim();
    _customerTenantId = _orderTenantId;
    TenantService().currentTenant.addListener(_handleTenantChanged);
    if (_orderTenantId != null && _orderTenantId!.isNotEmpty) {
      unawaited(_restoreOrderStateForTenant(_orderTenantId!));
      unawaited(_restoreGroupSessionForTenant(_orderTenantId!));
      unawaited(_restoreCustomerSessionForTenant(_orderTenantId!));
    }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _isAppInForeground = false;
      _stopBackgroundPolling();
    } else if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      _resumeBackgroundPolling();
    }
  }

  void _stopBackgroundPolling() {
    _musicTimer?.cancel();
    _notificationsTimer?.cancel();
    _waveTimer?.cancel();
    _presenceTimer?.cancel();
    _orderSyncTimer?.cancel();
    _chatTimer?.cancel();
    _orderStatusTimer?.cancel();
    _sessionPoller?.cancel();
  }

  void _resumeBackgroundPolling() {
    _startMusicPoller();
    _startWavePoller();
    _startNotificationsPoller();
    _startPresenceCheckIn();
    _startOrderSyncPoller();
    _startChatPoller();
    if (activeOrderId.value != null) _startStatusSync();
    if (activeSessionId.value != null) {
      startSessionPolling(
        activeSessionId.value!,
        isSessionHost.value,
        pin: activeSessionPin.value,
      );
    }
    refreshNotifications();
    refreshConversations();
    _pollIncomingWaves();
    updatePresenceOnServer();
    _syncOrderChanges();
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

  Timer? _orderSyncTimer;
  bool _initialTableRefreshStarted = false;

  void _startOrderSyncPoller() {
    _orderSyncTimer?.cancel();
    if (!_isAppInForeground) return;
    _orderSyncTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
      await _syncOrderChanges();
    });
  }

  Future<void> _syncOrderChanges() async {
    await refreshLiveOrders();
  }

  // --- CHAT POLLING ---
  Timer? _chatTimer;
  final ValueNotifier<List<Map<String, dynamic>>> conversations = ValueNotifier(
    [],
  );
  final ValueNotifier<int> totalUnreadChatCount = ValueNotifier<int>(0);

  void _startChatPoller() {
    _chatTimer?.cancel();
    if (!_isAppInForeground) return;
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

    final tables = await ApiService.fetchTables(tenant.id);
    if (tables == null) {
      tableStatuses.value = {};
      tableOrders.value = {};
      return;
    }
    final serverStatuses = <int, String>{};
    for (final table in tables) {
      final tableNumber = int.tryParse(table['table_number']?.toString() ?? '');
      if (tableNumber == null) continue;
      serverStatuses[tableNumber] = table['status']?.toString() ?? 'Available';
    }
    tableStatuses.value = serverStatuses;

    final List<Map<String, dynamic>>? orders =
        await ApiService.fetchActiveOrders(tenant.id);
    if (orders == null) {
      tableOrders.value = {};
      return;
    }

    Map<int, List<CartItem>> newOrders = {};

    for (var order in orders) {
      int tNum = int.tryParse(order['table_number']?.toString() ?? '') ?? 0;
      if (tNum == 0) continue;

      final List<dynamic> rawItems = order['items'] ?? [];
      final List<CartItem> itemsList = rawItems
          .map(
            (i) => CartItem(
              product: Product(
                productId: int.tryParse(i['product_id']?.toString() ?? ''),
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
    _musicTimer?.cancel();
    if (!_isAppInForeground) return;
    _musicTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => refreshMusicStatus(),
    );
    refreshMusicStatus();
  }

  final Set<int> _deletedSongIds = {};
  String? _musicTenantId;

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
    final tenantId = tenant?.id.trim() ?? '';
    if (tenantId.isEmpty) {
      _clearMusicState();
      musicApiStatusMessage.value = 'Select a restaurant to load music.';
      return;
    }

    if (_musicTenantId != tenantId) {
      _musicTenantId = tenantId;
      _deletedSongIds.clear();
      _clearMusicState();
    }

    final data = await ApiService.fetchMusicStatus(
      tenantId,
      userId: currentUserId,
    );
    if (_musicTenantId != tenantId ||
        TenantService().currentTenant.value?.id != tenantId) {
      return;
    }

    if (data != null && data['status'] == 'success') {
      final nowPlaying = data['now_playing'];
      currentSong.value = nowPlaying is Map<String, dynamic>
          ? Map<String, dynamic>.from(nowPlaying)
          : _emptyMusicState();
      final rawQueue = data['queue'];
      final serverQueue = rawQueue is List
          ? rawQueue.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      musicQueue.value = serverQueue.where((item) {
        final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
        return !_deletedSongIds.contains(id);
      }).toList();
      musicApiStatusMessage.value =
          "Connected to tenant '$tenantId'. DB returned ${musicQueue.value.length} song request(s).";
      final poll = data['active_poll'];
      activePoll.value = poll is Map<String, dynamic>
          ? Map<String, dynamic>.from(poll)
          : null;
      return;
    }

    _clearMusicState();
    musicApiStatusMessage.value =
        "Music service is unavailable for restaurant '$tenantId'.";
  }

  Map<String, dynamic> _emptyMusicState() => {
    'title': 'No Song Playing',
    'artist': '-',
    'image':
        'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
    'progress': 0.0,
  };

  void _clearMusicState() {
    musicQueue.value = [];
    currentSong.value = _emptyMusicState();
    activePoll.value = null;
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
    final notificationId = int.tryParse(
      message.data['notification_id']?.toString() ?? '',
    );
    if (notificationId != null) {
      await acknowledgeNotification(notificationId);
    }
    await refreshNotifications();
    await refreshConversations();
  }

  Future<void> acknowledgeNotification(int notificationId) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null ||
        !isEmailSynced.value ||
        customerSessionToken.isEmpty ||
        customerEmail.value.isEmpty) {
      return;
    }
    final acknowledged = await ApiService.acknowledgeNotification(
      tenantId: tenant.id,
      userId: customerEmail.value,
      notificationId: notificationId,
      sessionToken: customerSessionToken,
    );
    if (acknowledged) {
      notificationsList.value = notificationsList.value.map((item) {
        if (int.tryParse(item['id']?.toString() ?? '') == notificationId) {
          return {...item, 'is_read': 1};
        }
        return item;
      }).toList();
      await _cacheNotifications(
        tenant.id,
        orderUserId,
        notificationsList.value,
      );
    }
  }

  void _startNotificationsPoller() {
    _notificationsTimer?.cancel();
    if (!_isAppInForeground) return;
    _notificationsTimer = Timer.periodic(
      const Duration(seconds: 15),
      (timer) => refreshNotifications(),
    );
  }

  int _lastUnseenCount = 0;
  bool _hasLoadedNotifications = false;
  final ValueNotifier<int> unseenNotificationsCount = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> notificationsList =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  Future<void> refreshNotifications() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || orderUserId.isEmpty) return;
    final uid = orderUserId;
    final cached = await _readCachedNotifications(tenant.id, uid);
    if (cached.isNotEmpty) {
      notificationsList.value = cached;
      final cachedUnseen = cached.where((item) {
        final value = item['is_read'];
        return value == 0 || value == false || value?.toString() == '0';
      }).length;
      unseenNotificationsCount.value = cachedUnseen;
      _lastUnseenCount = cachedUnseen;
    }

    try {
      final data = await ApiService.fetchNotifications(
        tenant.id,
        uid,
        sessionToken: customerSessionToken,
      );
      if (data != null && data['status'] == 'success') {
        final serverList = List<Map<String, dynamic>>.from(data['data'] ?? []);
        final byId = <String, Map<String, dynamic>>{
          for (final item in cached)
            if (item['id'] != null) item['id'].toString(): item,
        };
        for (final item in serverList) {
          final id = item['id']?.toString();
          if (id != null && id.isNotEmpty) byId[id] = item;
        }
        final merged = byId.values.toList()
          ..sort((a, b) {
            final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
            final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });
        final serverUnseen =
            int.tryParse(data['unseen_count']?.toString() ?? '') ?? 0;
        final cachedUnseen = merged.where((item) {
          final value = item['is_read'];
          return value == 0 || value == false || value?.toString() == '0';
        }).length;
        final unseen = serverUnseen > cachedUnseen
            ? serverUnseen
            : cachedUnseen;

        if (_hasLoadedNotifications &&
            unseen > _lastUnseenCount &&
            merged.isNotEmpty) {
          final topNotif = merged.first;
          latestIncomingPush.value = {
            'title': topNotif['title'] ?? 'New Notification',
            'body': topNotif['message'] ?? '',
          };
        }

        _hasLoadedNotifications = true;
        _lastUnseenCount = unseen;
        notificationsList.value = merged;
        unseenNotificationsCount.value = unseen;
        await _cacheNotifications(tenant.id, uid, merged);
      }
    } catch (error) {
      debugPrint("Notification refresh failed: $error");
    }
  }

  String _notificationCacheKey(String tenantId, String userId) =>
      'notifications_${Uri.encodeComponent(tenantId)}_${Uri.encodeComponent(userId)}';

  Future<List<Map<String, dynamic>>> _readCachedNotifications(
    String tenantId,
    String userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_notificationCacheKey(tenantId, userId));
      if (encoded == null || encoded.isEmpty) return [];
      final decoded = json.decode(encoded);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      debugPrint("Could not load cached notifications: $error");
      return [];
    }
  }

  Future<void> _cacheNotifications(
    String tenantId,
    String userId,
    List<Map<String, dynamic>> notifications,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _notificationCacheKey(tenantId, userId),
        json.encode(notifications),
      );
    } catch (error) {
      debugPrint("Could not save cached notifications: $error");
    }
  }

  Future<void> clearNotificationBadge() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || orderUserId.isEmpty) return;
    if (await ApiService.markNotificationsRead(
      tenant.id,
      orderUserId,
      sessionToken: customerSessionToken,
    )) {
      _lastUnseenCount = 0;
      unseenNotificationsCount.value = 0;
      notificationsList.value = notificationsList.value
          .map((item) => {...item, 'is_read': 1})
          .toList();
      await _cacheNotifications(
        tenant.id,
        orderUserId,
        notificationsList.value,
      );
    }
  }

  void _startWavePoller() {
    _waveTimer?.cancel();
    if (!_isAppInForeground) return;
    _waveTimer = Timer.periodic(
      const Duration(seconds: 12),
      (timer) => _pollIncomingWaves(),
    );
  }

  Future<void> _pollIncomingWaves() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || currentUserId.isEmpty) return;

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

  void _startPresenceCheckIn() {
    _presenceTimer?.cancel();
    if (!_isAppInForeground) return;
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 45),
      (timer) => updatePresenceOnServer(),
    );
  }

  Future<void> updatePresenceOnServer() async {
    await ensureInitialized();
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id.trim() ?? '';
    final uid = currentUserId.trim();

    if (_presencePausedTenantId == tenantId) return;
    if (_presencePausedTenantId != null &&
        _presencePausedTenantId != tenantId) {
      _presencePausedTenantId = null;
    }

    if (tenantId.isNotEmpty && uid.isNotEmpty) {
      final previousTenantId = _lastPresenceTenantId;
      final previousUserId = _lastPresenceUserId;
      if (previousTenantId != null &&
          previousUserId != null &&
          (previousTenantId != tenantId ||
              previousUserId.toLowerCase() != uid.toLowerCase())) {
        await ApiService.goOffline(
          tenantId: previousTenantId,
          userId: previousUserId,
        );
      }

      // If table is not selected, we use 0 to indicate "Browsing/Near"
      int tableNum = selectedTableId.value ?? 0;

      debugPrint("NEARBY: Updating presence for $uid at Table $tableNum");
      final checkedIn = await ApiService.updatePresence(
        tenantId: tenantId,
        userId: uid,
        tableNumber: tableNum,
        userName: customerName.value.isNotEmpty ? customerName.value : null,
      );
      if (_presencePausedTenantId == tenantId) {
        await ApiService.goOffline(tenantId: tenantId, userId: uid);
        return;
      }
      if (checkedIn &&
          TenantService().currentTenant.value?.id == tenantId &&
          currentUserId.toLowerCase() == uid.toLowerCase()) {
        _lastPresenceTenantId = tenantId;
        _lastPresenceUserId = uid;
      }
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
    String? savedGuestId = prefs.getString('guest_id');
    if (savedGuestId == null ||
        savedGuestId.trim().isEmpty ||
        savedGuestId.toLowerCase() == 'guest') {
      savedGuestId =
          'guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      guestId.value = savedGuestId;
      await prefs.setString('guest_id', savedGuestId);
    } else {
      guestId.value = savedGuestId;
    }

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

    await fetchLoyaltySettings();
    await refreshUserPoints();
    await refreshSocialStats();
    await fetchSocialLists();
    await refreshNotifications();
    await fetchReviews(); // Fetch reviews on load
    checkNotificationPermission();
  }

  String _orderPreferenceKey(String tenantId, String name) =>
      'active_order_${Uri.encodeComponent(tenantId)}_$name';

  String _tenantPreferenceKey(String tenantId, String name) =>
      'tenant_${Uri.encodeComponent(tenantId)}_$name';

  String _customerPreferenceKey(String tenantId, String name) =>
      'customer_${Uri.encodeComponent(tenantId)}_$name';

  void _handleTenantChanged() {
    final tenantId = TenantService().currentTenant.value?.id.trim() ?? '';
    if (_orderTenantId == tenantId) return;

    _orderStatusTimer?.cancel();
    _clearSessionStateForTenantChange();
    _orderTenantId = tenantId;
    activeOrderIds.value = [];
    activeOrderId.value = null;
    activeOrderNumber.value = null;
    isOrderActive.value = false;
    orderStatus.value = OrderStatus.pending;
    customerEmail.value = '';
    customerSessionToken = '';
    customerName.value = 'Guest';
    userGender.value = 'Male';
    isEmailSynced.value = false;
    needsPin.value = false;
    userPoints.value = 0;
    orderStampCount.value = 0;
    isProfileVisible.value = true;
    isWaveEnabled.value = true;
    _customerTenantId = tenantId;
    if (tenantId.isNotEmpty) {
      unawaited(_restoreOrderStateForTenant(tenantId));
      unawaited(_restoreGroupSessionForTenant(tenantId));
      unawaited(_restoreCustomerSessionForTenant(tenantId));
    }
  }

  Future<void> _restoreCustomerSessionForTenant(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_customerTenantId != tenantId ||
        TenantService().currentTenant.value?.id != tenantId) {
      return;
    }

    final emailKey = _customerPreferenceKey(tenantId, 'email');
    final tokenKey = _customerPreferenceKey(tenantId, 'session_token');
    final authenticatedKey = _customerPreferenceKey(tenantId, 'authenticated');
    final lastActiveKey = _customerPreferenceKey(tenantId, 'last_active_time');
    final savedName = prefs.getString(_customerPreferenceKey(tenantId, 'name'));
    final savedGender = prefs.getString(
      _customerPreferenceKey(tenantId, 'gender'),
    );
    isOnboardingComplete.value =
        prefs.getBool(
          _customerPreferenceKey(tenantId, 'onboarding_complete'),
        ) ??
        false;
    if (savedName != null && savedName.trim().isNotEmpty) {
      customerName.value = savedName.trim();
    }
    if (savedGender != null && savedGender.trim().isNotEmpty) {
      userGender.value = savedGender.trim();
    }

    final savedEmail = prefs.getString(emailKey);
    customerSessionToken = prefs.getString(tokenKey) ?? '';
    final isAuth = prefs.getBool(authenticatedKey) ?? false;
    final lastActive = prefs.getInt(lastActiveKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const fiveMinutesMs = 5 * 60 * 1000;
    final active =
        savedEmail != null &&
        savedEmail.isNotEmpty &&
        isAuth &&
        now - lastActive < fiveMinutesMs;

    if (savedEmail != null && savedEmail.isNotEmpty) {
      customerEmail.value = savedEmail;
      if (active) {
        isEmailSynced.value = true;
        needsPin.value = false;
        await prefs.setInt(lastActiveKey, now);
        final res = await syncCustomerIdentity(savedEmail);
        if (_customerTenantId != tenantId ||
            TenantService().currentTenant.value?.id != tenantId) {
          return;
        }
        final user = res?['user'];
        if (user is Map) {
          final dbName = user['name']?.toString().trim();
          if (dbName != null &&
              dbName.isNotEmpty &&
              dbName != 'Diner' &&
              dbName != 'Guest Diner' &&
              dbName != 'Guest') {
            customerName.value = dbName;
            await prefs.setString(
              _customerPreferenceKey(tenantId, 'name'),
              dbName,
            );
          }
          userPoints.value =
              int.tryParse(user['points']?.toString() ?? '0') ?? 0;
          orderStampCount.value =
              int.tryParse(user['order_count']?.toString() ?? '0') ?? 0;
        }
        await _applyPendingEmailNotificationConsent(tenantId);
      } else {
        isEmailSynced.value = false;
        needsPin.value = false;
      }
    }
    if (!active) {
      userPoints.value = 0;
      orderStampCount.value = 0;
    }
    if (_customerTenantId == tenantId &&
        TenantService().currentTenant.value?.id == tenantId) {
      await updatePresenceOnServer();
    }
  }

  Future<void> _restoreGroupSessionForTenant(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_orderTenantId != tenantId ||
        TenantService().currentTenant.value?.id != tenantId) {
      return;
    }

    final sessionId = prefs.getInt(
      _tenantPreferenceKey(tenantId, 'session_id'),
    );
    if (sessionId == null) return;
    final isHost =
        prefs.getBool(_tenantPreferenceKey(tenantId, 'session_is_host')) ??
        false;
    final pin = prefs.getString(_tenantPreferenceKey(tenantId, 'session_pin'));
    startSessionPolling(sessionId, isHost, pin: pin);
  }

  void _clearSessionStateForTenantChange() {
    _sessionPoller?.cancel();
    liveSessionOrders.value = [];
    liveSessionMembers.value = [];
    liveSessionTotal.value = 0.0;
    isSessionHost.value = false;
    activeSessionId.value = null;
    activeSessionPin.value = null;
    activeSessionQr.value = null;
    isSessionLocked.value = false;
    isSplitShared.value = false;
    volunteerId.value = null;
    showPaymentPopup.value = false;
    currentGroupMembers.clear();
    _lastSyncTime = null;
  }

  Future<void> _restoreOrderStateForTenant(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_orderTenantId != tenantId ||
        TenantService().currentTenant.value?.id != tenantId) {
      return;
    }

    final savedIds =
        prefs.getStringList(_orderPreferenceKey(tenantId, 'ids')) ?? [];
    activeOrderIds.value = savedIds
        .map((id) => int.tryParse(id))
        .whereType<int>()
        .toList();
    activeOrderId.value = prefs.getInt(_orderPreferenceKey(tenantId, 'id'));
    activeOrderNumber.value = prefs.getInt(
      _orderPreferenceKey(tenantId, 'number'),
    );
    isOrderActive.value = activeOrderId.value != null;

    final savedStatus = prefs.getString(
      _orderPreferenceKey(tenantId, 'status'),
    );
    if (activeOrderId.value != null) {
      if (savedStatus != null) _mapStatus(savedStatus);
      _startStatusSync();
    }
  }

  Future<void> _persistOrder(
    int id, {
    bool isRemove = false,
    int? orderNumber,
  }) async {
    final tenantId = TenantService().currentTenant.value?.id.trim() ?? '';
    if (tenantId.isEmpty || tenantId != _orderTenantId) {
      throw StateError(
        'Cannot persist an order without the active restaurant.',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final idsKey = _orderPreferenceKey(tenantId, 'ids');
    final idKey = _orderPreferenceKey(tenantId, 'id');
    final numberKey = _orderPreferenceKey(tenantId, 'number');
    final statusKey = _orderPreferenceKey(tenantId, 'status');
    List<String> current = prefs.getStringList(idsKey) ?? [];
    if (isRemove)
      current.remove(id.toString());
    else if (!current.contains(id.toString()))
      current.add(id.toString());
    await prefs.setStringList(idsKey, current);
    activeOrderIds.value = current
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toList();
    if (isRemove) {
      if (prefs.getInt(idKey) == id) {
        final nextActiveId = current.isEmpty
            ? null
            : int.tryParse(current.last);
        if (nextActiveId == null) {
          await prefs.remove(idKey);
          await prefs.remove(numberKey);
        } else {
          await prefs.setInt(idKey, nextActiveId);
          await prefs.setInt(numberKey, nextActiveId);
        }
        activeOrderId.value = nextActiveId;
        activeOrderNumber.value = nextActiveId;
      }
    } else {
      await prefs.setInt(idKey, id);
      final resolvedOrderNumber = orderNumber ?? id;
      await prefs.setInt(numberKey, resolvedOrderNumber);
      await prefs.setString(statusKey, 'Pending');
      activeOrderId.value = id;
      activeOrderNumber.value = resolvedOrderNumber;
      orderStatus.value = OrderStatus.pending;
    }
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
    return orderUserId;
  }

  String get orderUserId {
    final staff = TenantService().currentStaff.value;
    if (staff != null) return staff.id.toString();
    if (isEmailSynced.value && customerEmail.value.trim().isNotEmpty) {
      return customerEmail.value.trim();
    }
    return ensureGuestId();
  }

  final ValueNotifier<List<int>> activeOrderIds = ValueNotifier<List<int>>([]);
  final ValueNotifier<int?> activeOrderId = ValueNotifier<int?>(null);
  final ValueNotifier<int?> activeOrderNumber = ValueNotifier<int?>(null);
  final ValueNotifier<String?> activeCategory = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isOrderActive = ValueNotifier<bool>(false);
  final ValueNotifier<OrderStatus> orderStatus = ValueNotifier<OrderStatus>(
    OrderStatus.pending,
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
    final activeId = activeOrderId.value;
    final activeIds = activeOrderIds.value;
    final orderIdsSet = <int>{
      if (activeId != null && activeId > 0) activeId,
      ...activeIds.where((i) => i > 0),
    };
    final orderIdsStr = orderIdsSet.isNotEmpty ? orderIdsSet.join(',') : null;

    final orderData = await ApiService.fetchUserOrders(
      tenant.id,
      orderUserId,
      customerEmail: customerEmail.value,
      guestId: guestId.value,
      orderIds: orderIdsStr,
    );
    int countFromApi = 0;
    if (orderData != null) {
      countFromApi =
          int.tryParse(orderData['total_count']?.toString() ?? '') ?? 0;
      double maxAmt =
          double.tryParse(orderData['max_amount']?.toString() ?? '0') ?? 0;
      if (maxAmt >= 1000) _checkAndSetQualifiedOrder(maxAmt);
    }
    final cachedOrders = await ApiService.getCachedUserOrders(
      tenant.id,
      orderUserId,
    );
    int localCount = activeOrderIds.value.length;
    totalOrdersCount.value = max(
      max(countFromApi, cachedOrders.length),
      localCount,
    );
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

  Future<void> refreshUserOrdersCount() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    try {
      final cached = await ApiService.getCachedUserOrders(
        tenant.id,
        currentUserId,
      );
      final res = await ApiService.fetchUserOrders(
        tenant.id,
        currentUserId,
        customerEmail: isEmailSynced.value ? customerEmail.value : null,
      );
      List orders = [];
      if (res != null && res['orders'] is List) {
        orders = res['orders'];
      }
      if (cached.length > orders.length) {
        totalOrdersCount.value = cached.length;
      } else {
        totalOrdersCount.value = orders.length;
      }
    } catch (e) {
      debugPrint("Error refreshing user orders count: $e");
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
    final tenantId = tenant?.id.trim() ?? '';
    if (tenantId.isEmpty || _musicTenantId != tenantId) {
      return {
        "success": false,
        "message": "Music voting is unavailable until restaurant data loads.",
      };
    }

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
    await refreshMusicStatus();
    return {"success": false};
  }

  Future<Map<String, dynamic>> requestSong(
    String title,
    String artist,
    String? dedication,
  ) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id.trim() ?? '';
    if (tenantId.isEmpty) {
      return {
        "success": false,
        "message": "Select a restaurant before requesting a song.",
      };
    }

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

  void initializeTables() {
    if (!_initialTableRefreshStarted) {
      _initialTableRefreshStarted = true;
      refreshLiveOrders();
    }
  }

  void settleTable(int tableId) {
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
    await ensureInitialized();
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      return {
        "success": false,
        "message": "Restaurant session is unavailable.",
      };
    }
    final List<CartItem> newItems = tableOrders.value[tableId] ?? [];
    List<Map<String, dynamic>> itemsJson = [];
    for (var item in newItems) {
      itemsJson.add({
        if (item.product.productId != null)
          "product_id": item.product.productId,
        if (item.product.variantName != null &&
            item.product.variantName!.isNotEmpty)
          "variant_name": item.product.variantName,
        "name": item.product.title,
        "quantity": item.quantity,
      });
    }
    final result = await ApiService.placeTableOrder({
      "tenant_id": tenant.id,
      "table_number": tableId,
      "idempotency_key": ApiService.newIdempotencyKey(),
      "user_id": orderUserId,
      "customer_email": isEmailSynced.value ? customerEmail.value : '',
      "items": itemsJson,
    });
    if (result != null && result['status'] == 'success') {
      final serverTotal = double.tryParse(
        result['total_amount']?.toString() ?? '',
      );
      if (serverTotal == null) {
        return {
          "success": false,
          "message": "The server did not return the accepted order total.",
        };
      }
      _checkAndSetQualifiedOrder(serverTotal);
      final Map<int, List<CartItem>> updated = Map.from(
        confirmedTableOrders.value,
      );
      updated[tableId] = (updated[tableId] ?? [])..addAll(newItems);
      confirmedTableOrders.value = updated;
      tableOrders.value = Map.from(tableOrders.value)..remove(tableId);
      return {"success": true};
    }
    return {
      "success": false,
      "message":
          result?['message']?.toString() ??
          "The server could not accept this order.",
    };
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

  Future<void> _clearCurrentPresence() async {
    final tenantId = TenantService().currentTenant.value?.id.trim() ?? '';
    final userId = currentUserId.trim();
    if (tenantId.isNotEmpty && userId.isNotEmpty) {
      await ApiService.goOffline(tenantId: tenantId, userId: userId);
    }
    if (_lastPresenceTenantId == tenantId &&
        _lastPresenceUserId?.toLowerCase() == userId.toLowerCase()) {
      _lastPresenceTenantId = null;
      _lastPresenceUserId = null;
    }
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
      await _clearCurrentPresence();
      // Clear previous user points immediately before switching to avoid coin leakage
      userPoints.value = 0;
      orderStampCount.value = 0;

      _presencePausedTenantId = null;
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
      customerSessionToken = (res['session_token'] ?? '').toString();
      await refreshUserPoints();
      await fetchSocialLists();
      await updatePresenceOnServer();
      await _saveCustomerSession(tenant.id);
      await _applyPendingEmailNotificationConsent(tenant.id);
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
      await _clearCurrentPresence();
      // Clear previous user points immediately before setting new user
      userPoints.value = 0;
      orderStampCount.value = 0;

      _presencePausedTenantId = null;
      customerEmail.value = email;
      customerName.value = userMap['name'] ?? 'Guest';
      needsPin.value = false;
      isEmailSynced.value = true;
      userPoints.value = userMap['points'] ?? 0;
      orderStampCount.value = userMap['order_count'] ?? 0;
      customerSessionToken = (saveResult['session_token'] ?? '').toString();
      await refreshUserPoints();
      await fetchSocialLists();
      await updatePresenceOnServer();
      await _saveCustomerSession(tenant.id);
      await _applyPendingEmailNotificationConsent(tenant.id);
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
      _presencePausedTenantId = null;
      needsPin.value = false;
      isEmailSynced.value = true;
      customerSessionToken = (saveResult['session_token'] ?? '').toString();
      await fetchSocialLists();
      await _saveCustomerSession(tenant.id);
      await _applyPendingEmailNotificationConsent(tenant.id);
      return true;
    }
    return false;
  }

  Future<void> touchUserSession() async {
    final tenantId = TenantService().currentTenant.value?.id.trim() ?? '';
    if (tenantId.isNotEmpty &&
        customerEmail.value.isNotEmpty &&
        isEmailSynced.value) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _customerPreferenceKey(tenantId, 'last_active_time'),
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _saveCustomerSession(String tenantId) async {
    if (TenantService().currentTenant.value?.id != tenantId ||
        _customerTenantId != tenantId) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customerPreferenceKey(tenantId, 'email'),
      customerEmail.value,
    );
    await prefs.setBool(
      _customerPreferenceKey(tenantId, 'authenticated'),
      isEmailSynced.value,
    );
    await prefs.setInt(
      _customerPreferenceKey(tenantId, 'last_active_time'),
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(
      _customerPreferenceKey(tenantId, 'name'),
      customerName.value,
    );
    await prefs.setString(
      _customerPreferenceKey(tenantId, 'gender'),
      userGender.value,
    );
    final tokenKey = _customerPreferenceKey(tenantId, 'session_token');
    if (customerSessionToken.isNotEmpty) {
      await prefs.setString(tokenKey, customerSessionToken);
    } else {
      await prefs.remove(tokenKey);
    }
  }

  Future<void> logoutCustomer() async {
    final tenant = TenantService().currentTenant.value;
    _presencePausedTenantId = tenant?.id.trim();
    await _clearCurrentPresence();
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
    userGender.value = 'Male';
    isOnboardingComplete.value = true;
    userPoints.value = 0;
    orderStampCount.value = 0;
    if (tenant != null) {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        'email',
        'session_token',
        'authenticated',
        'last_active_time',
      ]) {
        await prefs.remove(_customerPreferenceKey(tenant.id, key));
      }
    }
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
      final tenantId = tenant.id;
      await prefs.setBool(
        _customerPreferenceKey(tenantId, 'onboarding_complete'),
        true,
      );
      await prefs.setString(_customerPreferenceKey(tenantId, 'name'), name);
      await prefs.setString(_customerPreferenceKey(tenantId, 'gender'), gender);
      await refreshSocialStats();
      await fetchSocialLists();
      await setupPushNotifications();
      await updatePresenceOnServer();
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
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
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
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint(
          'Push notifications are not authorized; permission must be requested from a user action.',
        );
        return false;
      }
      final registered = await _registerPushToken(messaging);
      return registered;
    } catch (e, stackTrace) {
      debugPrint('Push notification setup failed: $e\n$stackTrace');
      return false;
    }
  }

  Future<NotificationPermissionResult>
  requestNotificationPermissionAndEnableEmail() async {
    try {
      await _recordEmailNotificationConsent();
      if (Firebase.apps.isEmpty) {
        debugPrint('Firebase is not initialized; cannot request notifications.');
        return NotificationPermissionResult.emailEnabled;
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final status = settings.authorizationStatus;
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        await _dismissNotificationPromptAndPersist();
        return NotificationPermissionResult.emailEnabled;
      }

      final registered = await _registerPushToken(messaging);
      await _dismissNotificationPromptAndPersist();
      if (!registered) {
        debugPrint(
          'Notification permission is granted, but push token registration did not complete.',
        );
        return NotificationPermissionResult.emailEnabled;
      }
      return NotificationPermissionResult.enabled;
    } catch (e, stackTrace) {
      debugPrint('Notification permission request failed: $e\n$stackTrace');
      await _dismissNotificationPromptAndPersist();
      return NotificationPermissionResult.emailEnabled;
    }
  }

  Future<void> _recordEmailNotificationConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = TenantService().currentTenant.value?.id.trim() ?? '';
    if (tenantId.isEmpty) return;

    final email = isEmailSynced.value ? customerEmail.value.trim() : '';
    if (email.isEmpty) {
      await prefs.setBool(
        _customerPreferenceKey(
          tenantId,
          'notification_email_opt_in_pending',
        ),
        true,
      );
    } else if (prefs.getBool(_notificationEmailConsentKey(tenantId, email)) !=
        true) {
      await prefs.setBool(
        _notificationEmailConsentKey(tenantId, email, pending: true),
        true,
      );
    }
    await _applyPendingEmailNotificationConsent(tenantId);
  }

  Future<void> _dismissNotificationPromptAndPersist() async {
    showNotificationPrompt.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_prompt_dismissed', true);
  }

  Future<void> dismissNotificationPrompt() async {
    await _dismissNotificationPromptAndPersist();
  }

  Future<void> _applyPendingEmailNotificationConsent(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    final email = customerEmail.value.trim();
    if (TenantService().currentTenant.value?.id != tenantId ||
        !isEmailSynced.value ||
        email.isEmpty ||
        customerSessionToken.isEmpty) {
      return;
    }
    final consentKey = _notificationEmailConsentKey(tenantId, email, pending: true);
    final guestConsentKey = _customerPreferenceKey(
      tenantId,
      'notification_email_opt_in_pending',
    );
    if (prefs.getBool(consentKey) != true &&
        prefs.getBool(guestConsentKey) != true) {
      return;
    }

    final current = await ApiService.fetchEmailNotificationPreferences(
      tenantId: tenantId,
      sessionToken: customerSessionToken,
    );
    if (current == null) {
      debugPrint('Could not load email preferences after notification consent.');
      return;
    }
    final preferences = <String, bool>{
      'email_enabled': true,
      'email_follow': current['email_follow'] == true ||
          current['email_follow']?.toString() == '1',
      'email_wave': current['email_wave'] == true ||
          current['email_wave']?.toString() == '1',
      'email_message': current['email_message'] == true ||
          current['email_message']?.toString() == '1',
    };
    final saved = await ApiService.saveEmailNotificationPreferences(
      tenantId: tenantId,
      sessionToken: customerSessionToken,
      preferences: preferences,
    );
    if (saved) {
      await prefs.remove(consentKey);
      await prefs.remove(guestConsentKey);
      await prefs.setBool(_notificationEmailConsentKey(tenantId, email), true);
    } else {
      debugPrint('Could not enable email alerts after notification consent.');
    }
  }

  String _notificationEmailConsentKey(
    String tenantId,
    String email, {
    bool pending = false,
  }) => _customerPreferenceKey(
    tenantId,
    'notification_email_${pending ? 'pending' : 'enabled'}_${Uri.encodeComponent(email.toLowerCase())}',
  );

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

    final registrationKey =
        'fcm_registered_token_${Uri.encodeComponent(tenant.id)}_${Uri.encodeComponent(userId)}';
    final prefs = await SharedPreferences.getInstance();
    final persistedToken = prefs.getString(registrationKey);
    if ((token == _lastRegisteredFcmToken &&
            registrationKey == _lastRegisteredFcmKey) ||
        token == persistedToken) {
      _lastRegisteredFcmToken = token;
      _lastRegisteredFcmKey = registrationKey;
      return true;
    }

    final saved = await ApiService.updateFcmToken(
      tenantId: tenant.id,
      userId: userId,
      token: token,
    );
    if (saved) {
      _lastRegisteredFcmToken = token;
      _lastRegisteredFcmKey = registrationKey;
      await prefs.setString(registrationKey, token);
    } else {
      debugPrint('Server did not save the FCM registration token.');
    }
    return saved;
  }

  Future<void> checkOrRequestNotificationOnAction() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('notif_prompt_dismissed') != true) {
        showNotificationPrompt.value = true;
        }
      } else if (settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _registerPushToken(messaging);
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

  final ValueNotifier<List<Map<String, dynamic>>> allHistoricalBills =
      ValueNotifier([]);
  final ValueNotifier<Map<String, dynamic>> inventoryStock = ValueNotifier({});
  final ValueNotifier<List<Map<String, dynamic>>> staffDirectory =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> departmentsList =
      ValueNotifier([]);

  Future<void> fetchCentralDepartments([String? tid]) async {
    final tenant = TenantService().currentTenant.value;
    final id = (tid ?? tenant?.id ?? '').trim();
    if (id.isEmpty) {
      departmentsList.value = [];
      return;
    }
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
          productId: int.tryParse(p['id']?.toString() ?? ''),
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

  Future<String?> placeOrder() async {
    // If an order is already active and cart is empty, skip
    if (activeOrderId.value != null && items.value.isEmpty) {
      return null;
    }

    await ensureInitialized();

    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id.trim() ?? '';
    if (tenantId.isEmpty) {
      return "Could not identify this restaurant. Reload and try again.";
    }

    if (selectedTableId.value == null || selectedTableId.value! <= 0) {
      return "Select a valid table before placing the order.";
    }

    if (items.value.isEmpty) {
      debugPrint("placeOrder: Cart items are empty, skipping order placement.");
      return null;
    }

    final currentItems = List<CartItem>.from(items.value);
    final itemsJson = currentItems
        .map(
          (i) => {
            if (i.product.productId != null) "product_id": i.product.productId,
            if (i.product.variantName != null &&
                i.product.variantName!.isNotEmpty)
              "variant_name": i.product.variantName,
            "name": i.product.title,
            "quantity": i.quantity,
          },
        )
        .toList();

    int? confirmedOrderId;
    int? confirmedOrderNumber;
    String? rejectedOrderMessage;
    final orderUserIdForSubmission = orderUserId;

    try {
      final result = await ApiService.placeTableOrder({
        "tenant_id": tenantId,
        "table_number": selectedTableId.value,
        "idempotency_key": ApiService.newIdempotencyKey(),
        "user_id": orderUserIdForSubmission,
        "customer_email": isEmailSynced.value ? customerEmail.value : '',
        "items": itemsJson,
      });

      if (result != null && result['status'] == 'success') {
        final id = int.tryParse(result['order_id']?.toString() ?? '');
        final orderNumber = int.tryParse(
          result['order_number']?.toString() ?? '',
        );
        final serverTotal = double.tryParse(
          result['total_amount']?.toString() ?? '',
        );
        if (id != null && id > 0 && serverTotal != null) {
          confirmedOrderId = id;
          confirmedOrderNumber = orderNumber;
          await ApiService.cacheUserOrders(tenantId, orderUserIdForSubmission, [
            {
              "id": id,
              "tenant_order_number": orderNumber ?? id,
              "tenant_id": tenantId,
              "table_number": selectedTableId.value,
              "user_id": orderUserIdForSubmission,
              "customer_email": isEmailSynced.value ? customerEmail.value : '',
              "total_amount": serverTotal,
              "status": "Pending",
              "created_at": DateTime.now().toIso8601String(),
              "items": result['items'] is List ? result['items'] : itemsJson,
            },
          ]);
          _checkAndSetQualifiedOrder(serverTotal);
        }
      } else if (result?['status'] == 'error') {
        rejectedOrderMessage =
            result?['message']?.toString() ?? 'The server rejected this order.';
      }
    } catch (e) {
      debugPrint("ApiService.placeTableOrder request failed: $e");
    }

    if (rejectedOrderMessage != null) return rejectedOrderMessage;
    if (confirmedOrderId == null) {
      return "The server could not confirm this order. Check your connection and retry.";
    }
    if (TenantService().currentTenant.value?.id != tenantId) {
      return "The restaurant changed while this order was being confirmed. Check the original restaurant's order history before retrying.";
    }
    activeOrderId.value = confirmedOrderId;

    await refreshLiveOrders();

    try {
      await _persistOrder(confirmedOrderId, orderNumber: confirmedOrderNumber);
    } catch (e) {
      debugPrint("Order was saved, but local order history failed: $e");
    }

    totalOrdersCount.value = max(
      totalOrdersCount.value + 1,
      activeOrderIds.value.length,
    );

    clearCart();
    isOrderActive.value = true;
    _startStatusSync();
    return null;
  }

  void _startStatusSync() {
    _orderStatusTimer?.cancel();
    if (!_isAppInForeground) return;
    Future<void> syncStatus() async {
      final tenantId = TenantService().currentTenant.value?.id.trim() ?? '';
      final id = activeOrderId.value;
      if (id == null || tenantId.isEmpty || tenantId != _orderTenantId) return;
      final live = await ApiService.fetchOrderStatus(id, tenantId: tenantId);
      if (_orderTenantId != tenantId ||
          TenantService().currentTenant.value?.id != tenantId ||
          activeOrderId.value != id) {
        return;
      }
      if (live == null) return;
      _mapStatus(live);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_orderPreferenceKey(tenantId, 'status'), live);
      if (live.toLowerCase() == 'completed' ||
          live.toLowerCase() == 'cancelled' ||
          live.toLowerCase() == 'canceled') {
        isOrderActive.value = false;
        _orderStatusTimer?.cancel();
      }
    }

    syncStatus();
    _orderStatusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => syncStatus(),
    );
  }

  void _mapStatus(String dbStatus) {
    switch (dbStatus.trim().toLowerCase()) {
      case 'approved':
        orderStatus.value = OrderStatus.approved;
        break;
      case 'cooking':
      case 'preparing':
        orderStatus.value = OrderStatus.preparing;
        break;
      case 'ready':
      case 'onway':
        orderStatus.value = OrderStatus.ready;
        break;
      default:
        orderStatus.value = OrderStatus.pending;
    }
  }

  Future<void> clearActiveOrder() async {
    _orderStatusTimer?.cancel();
    isOrderActive.value = false;
    activeOrderId.value = null;
    activeOrderNumber.value = null;
    placedOrderItems.value = [];
    orderStatus.value = OrderStatus.pending;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('active_order_state_initialized', true);
    await prefs.remove('active_order_id');
    await prefs.remove('active_order_number');
    await prefs.remove('active_order_status');
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
    if (_isAppInForeground) {
      _sessionPoller = Timer.periodic(
        const Duration(seconds: 8),
        (timer) => syncSessionData(),
      );
      syncSessionData();
    }

    // PERSIST SESSION
    final prefs = await SharedPreferences.getInstance();
    final tenantId = TenantService().currentTenant.value?.id.trim() ?? '';
    if (tenantId.isEmpty || tenantId != _orderTenantId) return;
    await prefs.setInt(_tenantPreferenceKey(tenantId, 'session_id'), sid);
    await prefs.setBool(
      _tenantPreferenceKey(tenantId, 'session_is_host'),
      asHost,
    );
    if (pin != null) {
      await prefs.setString(_tenantPreferenceKey(tenantId, 'session_pin'), pin);
    }
  }

  Future<void> syncSessionData() async {
    final tenant = TenantService().currentTenant.value;
    final sessionId = activeSessionId.value;
    if (tenant == null || sessionId == null || tenant.id != _orderTenantId) {
      return;
    }

    final result = await ApiService.getSplitGroupDetails(
      tenantId: tenant.id,
      sessionId: sessionId,
      lastSyncTime: _lastSyncTime,
    );
    if (TenantService().currentTenant.value?.id != tenant.id ||
        activeSessionId.value != sessionId) {
      return;
    }

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
    if (tenant != null) {
      await prefs.remove(_tenantPreferenceKey(tenant.id, 'session_id'));
      await prefs.remove(_tenantPreferenceKey(tenant.id, 'session_is_host'));
      await prefs.remove(_tenantPreferenceKey(tenant.id, 'session_pin'));
    }
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
