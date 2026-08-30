import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'dart:async';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

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
  }

  Future<void> _loadPersistedOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList('active_order_ids');
    if (savedIds != null && savedIds.isNotEmpty) {
      activeOrderIds.value = savedIds.map((id) => int.parse(id)).toList();
      isOrderActive.value = true;
      _startStatusSync();
    }
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
  final ValueNotifier<bool> isTenantActive = ValueNotifier<bool>(true); // Remote Kill-Switch State
  final ValueNotifier<int> selectedTableId = ValueNotifier<int>(12); // Default Table 12
  final ValueNotifier<bool> isQrLaunch = ValueNotifier<bool>(false); // NEW: State Lock
  final ValueNotifier<List<int>> activeOrderIds = ValueNotifier<List<int>>([]); // Persistent list
  final ValueNotifier<int?> activeOrderId = ValueNotifier<int?>(null); 
  final ValueNotifier<String?> activeCategory = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isOrderActive = ValueNotifier<bool>(false);
  final ValueNotifier<OrderStatus> orderStatus = ValueNotifier<OrderStatus>(OrderStatus.pending);
  final ValueNotifier<Duration> totalGameTime = ValueNotifier<Duration>(Duration.zero);

  // Procurement Central State
  final ValueNotifier<List<Map<String, dynamic>>> allPurchases = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<List<Map<String, dynamic>>> allSuppliers = ValueNotifier<List<Map<String, dynamic>>>([]);

  Future<void> syncProcurementData(String tenantId) async {
    final supData = await ApiService.fetchSuppliers(tenantId);
    final purData = await ApiService.fetchPurchases(tenantId);
    if (supData != null) allSuppliers.value = supData;
    if (purData != null) allPurchases.value = purData;
  }

  // Coins & Group Management
  final ValueNotifier<int> orderCoins = ValueNotifier<int>(50);
  final ValueNotifier<int> groupCoins = ValueNotifier<int>(200);
  final ValueNotifier<int> orderStampCount = ValueNotifier<int>(8); // Initial mock value
  final ValueNotifier<bool> isGroupActive = ValueNotifier<bool>(false);
  final List<Map<String, dynamic>> currentGroupMembers = [];
  bool hasNewOrderCoins = false;

  // Mystery Box State
  final ValueNotifier<bool> isMysteryBoxOpened = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRewardClaimed = ValueNotifier<bool>(false);
  bool isConnectedToRestaurantWiFi = true; // Simulated WiFi connection

  // Social Wave State
  final ValueNotifier<Map<String, dynamic>?> activeWave = ValueNotifier<Map<String, dynamic>?>(null);

  // Privacy & Interaction Settings
  final ValueNotifier<bool> isLocationHidden = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isWaveEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showSocialStatus = ValueNotifier<bool>(true);
  final ValueNotifier<bool> onlyMutualChat = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showTableNumber = ValueNotifier<bool>(true);
  final ValueNotifier<bool> socialVibration = ValueNotifier<bool>(true);
  final ValueNotifier<bool> autoWaveBack = ValueNotifier<bool>(false);

  void sendWave(Map<String, dynamic> friend) {
    if (!isWaveEnabled.value) return; // Don't allow sending if disabled
    // Simulate receiving a wave back from the system for testing
    Future.delayed(const Duration(seconds: 3), () {
      if (isWaveEnabled.value) {
        activeWave.value = friend;
      }
    });
  }

  void clearWave() {
    activeWave.value = null;
  }

  // Table Service States
  final ValueNotifier<bool> isWaterRequested = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isWaiterRequested = ValueNotifier<bool>(false);
  final ValueNotifier<int> waterCooldown = ValueNotifier<int>(0);
  final ValueNotifier<int> waiterCooldown = ValueNotifier<int>(0);

  // Billing & Payment State
  final ValueNotifier<bool> isOrderPaid = ValueNotifier<bool>(false);

  // Music Jukebox Management
  final ValueNotifier<Map<String, dynamic>> currentSong = ValueNotifier<Map<String, dynamic>>({
    'title': 'Midnight City',
    'artist': 'M83',
    'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60',
    'progress': 0.45,
    'dedication': 'For Everyone @ Arby\'s',
  });

  // Meat Master Stamps
  final ValueNotifier<List<Map<String, dynamic>>> meatStamps = ValueNotifier<List<Map<String, dynamic>>>([
    {
      'id': 'beef',
      'name': 'Roast Beef',
      'icon': Icons.kebab_dining,
      'isCollected': true,
      'date': 'Aug 12, 2026',
    },
    {
      'id': 'brisket',
      'name': 'Smoke Brisket',
      'icon': Icons.outdoor_grill_rounded,
      'isCollected': true,
      'date': 'Aug 15, 2026',
    },
    {
      'id': 'chicken',
      'name': 'Classic Chicken',
      'icon': Icons.lunch_dining,
      'isCollected': false,
      'date': null,
    },
    {
      'id': 'turkey',
      'name': 'Roast Turkey',
      'icon': Icons.restaurant_rounded,
      'isCollected': false,
      'date': null,
    },
    {
      'id': 'bacon',
      'name': 'Pepper Bacon',
      'icon': Icons.bakery_dining_rounded,
      'isCollected': true,
      'date': 'Yesterday',
    },
  ]);

  bool get allStampsCollected {
    return orderStampCount.value >= 20;
  }

  final ValueNotifier<int> vibeScore = ValueNotifier<int>(65);

  // Poll Management
  final ValueNotifier<Map<String, dynamic>?> activePoll = ValueNotifier<Map<String, dynamic>?>(null);

  // Tap War Management
  final ValueNotifier<bool> isTapWarActive = ValueNotifier<bool>(false);
  final ValueNotifier<int> tapWarTimer = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> tapLeaderboard = ValueNotifier<List<Map<String, dynamic>>>([]);
  Timer? _gameTimer;

  void startTapWar() {
    isTapWarActive.value = true;
    tapWarTimer.value = 30; // 30 second battle
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
        // Mock opponent activity
        _mockOpponentTaps();
      } else {
        timer.cancel();
        // isTapWarActive.value = false; // We keep it true until the user exits the results
      }
    });
  }

  void _mockOpponentTaps() {
    List<Map<String, dynamic>> current = List.from(tapLeaderboard.value);
    for (var item in current) {
      if (!item['isUser']) {
        // Random taps between 2-8 per second
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

  // --- Waiter Mode & Table Tracking ---
  final ValueNotifier<Map<int, List<CartItem>>> tableOrders = ValueNotifier<Map<int, List<CartItem>>>({});
  final ValueNotifier<Map<int, List<CartItem>>> confirmedTableOrders = ValueNotifier<Map<int, List<CartItem>>>({}); // In Kitchen
  final ValueNotifier<Map<int, String>> tableStatuses = ValueNotifier<Map<int, String>>({});
  final ValueNotifier<Map<int, DateTime>> tableStartTimes = ValueNotifier<Map<int, DateTime>>({});
  final ValueNotifier<Map<int, int>> tableCountdownTimers = ValueNotifier<Map<int, int>>({}); // seconds
  final ValueNotifier<Map<int, int>> tableOriginalDurations = ValueNotifier<Map<int, int>>({});
  final ValueNotifier<Map<int, String>> tableKitchenStages = ValueNotifier<Map<int, String>>({}); // "Incoming", "Preparing", "Ready"
  final ValueNotifier<Map<int, bool>> tableReadyNotifications = ValueNotifier<Map<int, bool>>({});
  
  // Admin Pro Data
  final ValueNotifier<List<Map<String, dynamic>>> staffDirectory = ValueNotifier<List<Map<String, dynamic>>>([
    {'id': 'WT-101', 'name': 'Catherine', 'role': 'Waiter', 'pin': '1111', 'shift': 'Morning', 'sales': 45200, 'tips': 1200},
    {'id': 'WT-102', 'name': 'Noah', 'role': 'Waiter', 'pin': '2222', 'shift': 'Evening', 'sales': 32100, 'tips': 850},
    {'id': 'CH-001', 'name': 'Chef Yuvraj', 'role': 'Chef', 'pin': '0000', 'shift': 'Morning', 'sales': 0, 'tips': 0},
    {'id': 'CS-001', 'name': 'Sarah', 'role': 'Cashier', 'pin': '9999', 'shift': 'Full-time', 'sales': 88400, 'tips': 0},
  ]);

  final ValueNotifier<Map<String, dynamic>> inventoryStock = ValueNotifier<Map<String, dynamic>>({});

  final ValueNotifier<List<Map<String, dynamic>>> allHistoricalBills = ValueNotifier<List<Map<String, dynamic>>>([
    {
      'id': '146',
      'table': 'Table 7',
      'date': '20/08/2026',
      'timestamp': DateTime.now(), // Today
      'time': '10:35 AM',
      'items': [
        {'name': 'Iced Americano', 'qty': 2, 'price': 'NPR 600'},
        {'name': 'Croque-Monsieur', 'qty': 1, 'price': 'NPR 650'},
      ],
      'total': 'NPR 1,250',
      'status': 'Active',
      'server': 'Catherine',
    },
    {
      'id': '145',
      'table': 'Table 5',
      'date': '20/08/2026',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)), // Yesterday
      'time': '10:28 AM',
      'items': [
        {'name': 'Cold Brew', 'qty': 1, 'price': 'NPR 450'},
        {'name': 'Chiya', 'qty': 1, 'price': 'NPR 449'},
      ],
      'total': 'NPR 899',
      'status': 'Active',
      'server': 'Noah',
    },
    {
      'id': '144',
      'table': 'Table 1',
      'date': '20/08/2026',
      'timestamp': DateTime.now().subtract(const Duration(days: 2)), // Previous
      'time': '10:15 AM',
      'items': [
        {'name': 'Matcha Frappe', 'qty': 1, 'price': 'NPR 750'},
        {'name': 'Iced Black', 'qty': 1, 'price': 'NPR 750'},
      ],
      'total': 'NPR 1,500',
      'status': 'Billed',
      'server': 'Sarah',
    },
  ]);

  final ValueNotifier<int?> activeStaffTableId = ValueNotifier<int?>(null);
  final ValueNotifier<int> waiterTabIndex = ValueNotifier<int>(0); // Tables first
  final ValueNotifier<Map<int, Map<String, CartItem>>> pendingTableOrders = ValueNotifier<Map<int, Map<String, CartItem>>>({});

  void setPendingItem(int tableId, Map<String, dynamic> p, int qty) {
    Map<int, Map<String, CartItem>> allPending = Map.from(pendingTableOrders.value);
    Map<String, CartItem> tablePending = Map.from(allPending[tableId] ?? {});
    
    String title = p['title'];
    if (qty <= 0) {
      tablePending.remove(title);
    } else {
      Product product = Product(
        title: p['title'],
        price: p['price'],
        image: p['image'],
        tag: p['tag'] ?? "Staff",
        rating: p['rating'] ?? "N/A",
        discount: p['discount'] ?? "",
      );
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

  // Mock Sales Stats
  final Map<String, dynamic> salesStats = {
    'totalSales': 'NPR 145,943',
    'salesChange': '+14%',
    'totalOrders': '116',
    'ordersChange': '+11%',
    'avgOrderValue': 'NPR 8.12K',
    'avgValueChange': '-3%',
    'reservations': '34',
    'resChange': '-5%',
  };

  void initializeTables(int tablesPerFloor) {
    if (tableStatuses.value.isNotEmpty) return;
    Map<int, String> initialStatuses = {};
    // Floor 1 (IDs 101 to 120)
    for (int i = 1; i <= tablesPerFloor; i++) {
      initialStatuses[100 + i] = "Available";
    }
    // Floor 2 (IDs 201 to 220)
    for (int i = 1; i <= tablesPerFloor; i++) {
      initialStatuses[200 + i] = "Available";
    }
    tableStatuses.value = initialStatuses;
  }

  void updateTableStatus(int tableId, String status) {
    Map<int, String> current = Map.from(tableStatuses.value);
    current[tableId] = status;
    tableStatuses.value = current;

    // Track start time if occupied
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
    // Handles formats like "T-101", "Table 101", "101", "T-Floor1-101"
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

    // Start a default 10-minute prep timer if none exists
    if (!tableCountdownTimers.value.containsKey(tableId)) {
      startTableTimer(tableId, 10);
      updateKitchenStage(tableId, "Incoming");
    }

    // Sync with Bills tab (historical/active sessions)
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

  // Admin Methods
  void addStaff(Map<String, dynamic> staff) {
    List<Map<String, dynamic>> current = List.from(staffDirectory.value);
    current.add(staff);
    staffDirectory.value = current;
  }

  void updateInventory(String item, double newAmount) {
    Map<String, dynamic> current = Map.from(inventoryStock.value);
    if (current.containsKey(item)) {
      current[item]['amount'] = newAmount;
      // Update status logic
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
    
    // Check if an active bill for this table already exists
    int existingIdx = bills.indexWhere((b) => b['table'] == tableStr && b['status'] == 'Active');
    
    double totalValue = 0;
    List<Map<String, dynamic>> billItems = [];
    for (var item in items) {
      String priceStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', '');
      double price = double.tryParse(priceStr) ?? 0;
      totalValue += price * item.quantity;
      billItems.add({'name': item.product.title, 'qty': item.quantity, 'price': item.product.price});
    }

    Map<String, dynamic> billData = {
      'id': existingIdx != -1 ? bills[existingIdx]['id'] : '${147 + bills.length}',
      'table': tableStr,
      'date': '20/08/2026',
      'timestamp': existingIdx != -1 ? bills[existingIdx]['timestamp'] : DateTime.now(),
      'time': existingIdx != -1 ? bills[existingIdx]['time'] : 'Now',
      'items': billItems,
      'total': 'NPR ${totalValue.toStringAsFixed(0)}',
      'status': 'Active',
      'server': 'Catherine',
    };

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
    if (tenant == null) {
      return {"success": false, "message": "No tenant identified. Please refresh app."};
    }

    final List<CartItem> newItems = tableOrders.value[tableId] ?? [];
    if (newItems.isEmpty) {
      return {"success": false, "message": "Cart is empty."};
    }

    double total = 0;
    List<Map<String, dynamic>> itemsJson = [];
    for (var item in newItems) {
      double prc = double.tryParse(item.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
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
      "total_amount": total,
      "items": itemsJson,
    });

    if (result != null && result['status'] == 'success') {
      // Move to Confirmed
      Map<int, List<CartItem>> allConfirmed = Map.from(confirmedTableOrders.value);
      List<CartItem> existing = List.from(allConfirmed[tableId] ?? []);
      existing.addAll(newItems);
      allConfirmed[tableId] = existing;
      confirmedTableOrders.value = allConfirmed;

      // Clear Current Draft
      Map<int, List<CartItem>> currentOrders = Map.from(tableOrders.value);
      currentOrders.remove(tableId);
      tableOrders.value = currentOrders;

      return {"success": true};
    }
    
    return {
      "success": false, 
      "message": result != null ? result['message'] : "Server connection failed."
    };
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
    activePoll.value = {
      'title': title,
      'options': songs.map((s) => {...s, 'votes': 0}).toList(),
      'endTime': DateTime.now().add(const Duration(minutes: 5)),
      'userVotedIndex': -1,
      'totalVotes': 0,
    };
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
    {
      'title': 'Blinding Lights',
      'artist': 'The Weeknd',
      'image': 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=500&auto=format&fit=crop&q=60',
      'votes': 12,
      'hasVoted': false,
      'dedication': 'For Table 12',
    },
    {
      'title': 'Levitating',
      'artist': 'Dua Lipa',
      'image': 'https://images.unsplash.com/photo-1493225255756-d9584f8606e9?w=500&auto=format&fit=crop&q=60',
      'votes': 8,
      'hasVoted': false,
      'dedication': 'To my best friend!',
    },
    {
      'title': 'Heat Waves',
      'artist': 'Glass Animals',
      'image': 'https://images.unsplash.com/photo-1557672172-298e090bd0f1?w=500&auto=format&fit=crop&q=60',
      'votes': 5,
      'hasVoted': false,
      'dedication': null,
    },
  ]);

  void toggleMusicVote(int index) {
    List<Map<String, dynamic>> queue = List.from(musicQueue.value);
    bool currentVoted = queue[index]['hasVoted'];
    queue[index]['hasVoted'] = !currentVoted;
    queue[index]['votes'] += currentVoted ? -1 : 1;
    queue.sort((a, b) => b['votes'].compareTo(a['votes']));
    musicQueue.value = queue;
    
    // Boost vibe score on vote
    if (!currentVoted) vibeScore.value = (vibeScore.value + 2).clamp(0, 100);
  }

  void requestSong(String title, String artist, String? dedication) {
    List<Map<String, dynamic>> queue = List.from(musicQueue.value);
    queue.add({
      'title': title,
      'artist': artist,
      'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60',
      'votes': 1,
      'hasVoted': true,
      'dedication': dedication,
    });
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
    
    notifier.value = 120; // 2 minutes in seconds
    
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
    return hour >= 8 && hour < 20; // 8 AM to 8 PM
  }

  void addMembersToGroup(List<Map<String, dynamic>> members) {
    currentGroupMembers.addAll(members);
    groupCoins.value += (members.length * 200);
    isGroupActive.value = true;
  }

  void resetGroup() {
    isGroupActive.value = false;
    currentGroupMembers.clear();
  }

  // Mock Nearby Users Data (Localized to Restaurant)
  final List<Map<String, dynamic>> nearbyUsers = [
    {
      'name': 'Mark',
      'location': 'Table 12 (Lounge)',
      'distance': '2m away',
      'time': 'Since 3:12 pm',
      'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500&auto=format&fit=crop&q=60',
      'status': 'Eating Brisket',
      'battery': '92%',
      'isFollowing': true,
      'isFollowingMe': true,
      'lastMsg': 'Voice Note (0:12)',
      'unread': 0,
      'isOnline': false,
      'activeTable': null, // Available
    },
    {
      'name': 'Noah',
      'location': 'Table 4 (Window)',
      'distance': '5m away',
      'time': 'Since 4:45 pm',
      'image': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=500&auto=format&fit=crop&q=60',
      'status': 'Waiting for Order',
      'battery': '45%',
      'isFollowing': true,
      'isFollowingMe': true,
      'lastMsg': 'Come say hi later!',
      'unread': 2,
      'isOnline': true,
      'activeTable': 'Table 4', // Dining
    },
    {
      'name': 'Sarah',
      'location': 'Counter Bar',
      'distance': '1m away',
      'time': 'Since 5:30 pm',
      'image': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=500&auto=format&fit=crop&q=60',
      'status': 'Drinking Coffee',
      'battery': '88%',
      'isFollowing': false,
      'isFollowingMe': false,
      'lastMsg': '',
      'unread': 0,
      'isOnline': true,
    },
    {
      'name': 'Emily',
      'location': 'Outdoor Patio',
      'distance': '15m away',
      'time': 'Since 6:00 pm',
      'image': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=500&auto=format&fit=crop&q=60',
      'status': 'Reading Book',
      'battery': '70%',
      'isFollowing': false,
      'isFollowingMe': false,
      'lastMsg': '',
      'unread': 0,
      'isOnline': false,
    },
  ];

  List<Map<String, dynamic>> get mutualFriends {
    return nearbyUsers.where((user) => 
      (user['isFollowing'] ?? false) && (user['isFollowingMe'] ?? false)
    ).toList();
  }

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
      // Remove "NPR " and commas to parse the price
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
    if (tenant == null) {
      debugPrint("BACKEND ERROR: No tenant active. Login/Domain check failed.");
      return;
    }

    double total = totalPrice;
    final List<Map<String, dynamic>> itemsJson = items.value.map((i) => {
      "name": i.product.title,
      "quantity": i.quantity,
      "price": double.tryParse(i.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
    }).toList();

    debugPrint("BACKEND: Sending order to Hostinger for tenant: ${tenant.id}...");

    // 1. Send to Hostinger
    final result = await ApiService.placeTableOrder({
      "tenant_id": tenant.id,
      "table_number": selectedTableId.value,
      "total_amount": total,
      "items": itemsJson,
    });

    if (result != null && result['status'] == 'success') {
      debugPrint("BACKEND SUCCESS: Order saved with ID: ${result['order_id']}");
      
      placedOrderItems.value = List.from(items.value);
      int orderId = int.parse(result['order_id'].toString());
      
      // Persistence Fix: Store in list
      activeOrderId.value = orderId;
      await _persistOrder(orderId);
      
      clearCart();
      isOrderActive.value = true;
      orderStatus.value = OrderStatus.pending;
      
      _startStatusSync();
    } else {
      debugPrint("BACKEND FAILED: ${result?['message'] ?? 'Connection error'}");
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
      case 'Pending':
        orderStatus.value = OrderStatus.pending;
        break;
      case 'Approved':
        orderStatus.value = OrderStatus.approved;
        break;
      case 'Preparing':
        orderStatus.value = OrderStatus.preparing;
        break;
      case 'Ready':
        orderStatus.value = OrderStatus.ready;
        break;
      case 'Completed':
        clearActiveOrder(); // Remove from tracking when done
        break;
    }
  }

  Future<void> clearActiveOrder() async {
    isOrderActive.value = false;
    activeOrderId.value = null;
    placedOrderItems.value = [];
    orderStatus.value = OrderStatus.pending;
    _statusTimer?.cancel();
    
    // Clear all persistent orders from local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_order_ids');
    activeOrderIds.value = [];
  }

  void clearCart() {
    items.value = [];
  }

  void addGameTime(Duration sessionTime) {
    totalGameTime.value += sessionTime;
  }

  void switchTable(int id) {
    selectedTableId.value = id;
    // Potentially clear current cart if it's table-specific
    // clearCart();
  }

  int getItemQuantity(String title) {
    final index = items.value.indexWhere((i) => i.product.title == title);
    if (index != -1) {
      return items.value[index].quantity;
    }
    return 0;
  }

  void navigateToCategory(String? category) {
    activeCategory.value = category;
    currentTabIndex.value = 1; // Menu Tab
  }
}

final storeManager = ShopManager();
