import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String id;
  final String name;
  final String nativeName;
  final String code;
  bool status;
  bool isDefault;
  final DateTime createdAt;
  DateTime updatedAt;

  AppLanguage({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.code,
    this.status = true,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nativeName': nativeName,
      'code': code,
      'status': status,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppLanguage.fromMap(Map<String, dynamic> map) {
    return AppLanguage(
      id: map['id'],
      name: map['name'],
      nativeName: map['nativeName'],
      code: map['code'],
      status: map['status'] ?? true,
      isDefault: map['isDefault'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}

class AppTranslation {
  final String id;
  final String key;
  final String category;
  final Map<String, String> translations;
  bool status;

  AppTranslation({
    required this.id,
    required this.key,
    required this.category,
    required this.translations,
    this.status = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'key': key,
      'category': category,
      'translations': translations,
      'status': status,
    };
  }

  factory AppTranslation.fromMap(Map<String, dynamic> map) {
    return AppTranslation(
      id: map['id'],
      key: map['key'],
      category: map['category'],
      translations: Map<String, String>.from(map['translations']),
      status: map['status'] ?? true,
    );
  }
}

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  final ValueNotifier<String> currentLanguageCode = ValueNotifier<String>('en');
  final ValueNotifier<List<AppLanguage>> languages = ValueNotifier<List<AppLanguage>>([]);
  final ValueNotifier<List<AppTranslation>> translations = ValueNotifier<List<AppTranslation>>([]);
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    // 1. Load Languages
    String? langJson = prefs.getString('app_languages');
    if (langJson != null) {
      List<dynamic> list = json.decode(langJson);
      languages.value = list.map((m) => AppLanguage.fromMap(m)).toList();
    } else {
      // Default Languages
      languages.value = [
        AppLanguage(id: '1', name: 'English', nativeName: 'English', code: 'en', isDefault: true, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        AppLanguage(id: '2', name: 'Nepali', nativeName: 'नेपाली', code: 'ne', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        AppLanguage(id: '3', name: 'Hindi', nativeName: 'हिन्दी', code: 'hi', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      ];
      await _persistLanguages();
    }

    // 2. Load Translations
    String? transJson = prefs.getString('app_translations');
    if (transJson != null) {
      List<dynamic> list = json.decode(transJson);
      translations.value = list.map((m) => AppTranslation.fromMap(m)).toList();
    } else {
      // Default Base Translations
      translations.value = _getDefaultTranslations();
      await _persistTranslations();
    }

    // 3. Load Preference
    String? savedCode = prefs.getString('selected_language_code');
    if (savedCode != null) {
      currentLanguageCode.value = savedCode;
    } else {
      // Use default language
      final def = languages.value.firstWhere((l) => l.isDefault, orElse: () => languages.value.first);
      currentLanguageCode.value = def.code;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    // Check if active
    final lang = languages.value.firstWhere((l) => l.code == code, orElse: () => languages.value.first);
    if (!lang.status && code != 'en') return; // Cannot switch to inactive (en is fallback)

    currentLanguageCode.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language_code', code);
    notifyListeners();
  }

  String translate(String key) {
    if (key.trim().isEmpty) return key;
    
    final trans = translations.value.firstWhere(
      (t) => t.key.toLowerCase() == key.toLowerCase() || 
             (t.translations['en'] != null && t.translations['en']!.toLowerCase() == key.toLowerCase()), 
      orElse: () => AppTranslation(id: '', key: key, category: '', translations: {})
    );

    // 1. Current Language
    if (trans.translations.containsKey(currentLanguageCode.value) && trans.translations[currentLanguageCode.value]!.isNotEmpty) {
      return trans.translations[currentLanguageCode.value]!;
    }
    // 2. English Fallback
    if (trans.translations.containsKey('en') && trans.translations['en']!.isNotEmpty) {
      return trans.translations['en']!;
    }
    // 3. Key Fallback
    return key;
  }

  Future<void> addLanguage(AppLanguage lang) async {
    languages.value = List.from(languages.value)..add(lang);
    await _persistLanguages();
    notifyListeners();
  }

  Future<void> updateLanguage(AppLanguage lang) async {
    int idx = languages.value.indexWhere((l) => l.id == lang.id);
    if (idx != -1) {
      List<AppLanguage> newList = List.from(languages.value);
      newList[idx] = lang;
      languages.value = newList;
      await _persistLanguages();
      notifyListeners();
    }
  }

  Future<void> toggleDefaultLanguage(String id) async {
    List<AppLanguage> newList = languages.value.map((l) {
      if (l.id == id) {
        final bool newDefault = !l.isDefault;
        return AppLanguage(
          id: l.id,
          name: l.name,
          nativeName: l.nativeName,
          code: l.code,
          status: newDefault ? true : l.status, // Auto-enable if set as default
          isDefault: newDefault,
          createdAt: l.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return l;
    }).toList();
    languages.value = newList;
    await _persistLanguages();
    notifyListeners();
  }

  Future<void> toggleLanguageStatus(String id) async {
    List<AppLanguage> newList = languages.value.map((l) {
      if (l.id == id) {
        return AppLanguage(
          id: l.id,
          name: l.name,
          nativeName: l.nativeName,
          code: l.code,
          status: !l.status,
          isDefault: l.isDefault,
          createdAt: l.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return l;
    }).toList();
    languages.value = newList;
    await _persistLanguages();
    notifyListeners();
  }

  Future<void> deleteLanguage(String id) async {
    List<AppLanguage> newList = languages.value.where((l) => l.id != id).toList();
    languages.value = newList;
    await _persistLanguages();
    notifyListeners();
  }

  Future<void> _persistLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_languages', json.encode(languages.value.map((l) => l.toMap()).toList()));
  }

  Future<void> updateTranslation(AppTranslation trans) async {
    int idx = translations.value.indexWhere((t) => t.key == trans.key);
    if (idx != -1) {
      List<AppTranslation> newList = List.from(translations.value);
      newList[idx] = trans;
      translations.value = newList;
      await _persistTranslations();
    }
  }

  Future<void> _persistTranslations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_translations', json.encode(translations.value.map((t) => t.toMap()).toList()));
  }

  List<AppTranslation> _getDefaultTranslations() {
    return [
      // Navigation & Bottom Bar
      AppTranslation(id: '1', key: 'nav.dashboard', category: 'Navigation', translations: {'en': 'Dashboard', 'ne': 'ड्यासबोर्ड', 'hi': 'डैशबोर्ड'}),
      AppTranslation(id: '2', key: 'nav.kitchen', category: 'Navigation', translations: {'en': 'Kitchen', 'ne': 'भान्सा', 'hi': 'रसोई'}),
      AppTranslation(id: '3', key: 'nav.inventory', category: 'Navigation', translations: {'en': 'Inventory', 'ne': 'सूची', 'hi': 'वस्तु-सूची'}),
      AppTranslation(id: '4', key: 'nav.sales', category: 'Navigation', translations: {'en': 'Sales', 'ne': 'बिक्री', 'hi': 'बिक्री'}),
      AppTranslation(id: '5', key: 'nav.reports', category: 'Navigation', translations: {'en': 'Reports', 'ne': 'रिपोर्टहरू', 'hi': 'रिपोर्ट'}),
      AppTranslation(id: '6', key: 'nav.settings', category: 'Navigation', translations: {'en': 'Settings', 'ne': 'सेटिङहरू', 'hi': 'सेटिंग्स'}),
      AppTranslation(id: '7', key: 'nav.employees', category: 'Navigation', translations: {'en': 'Employees', 'ne': 'कर्मचारीहरू', 'hi': 'कर्मचारी'}),

      // Customer App Navigation
      AppTranslation(id: '10', key: 'Home', category: 'Customer', translations: {'en': 'Home', 'ne': 'गृहपृष्ठ', 'hi': 'होम'}),
      AppTranslation(id: '11', key: 'Menu', category: 'Customer', translations: {'en': 'Menu', 'ne': 'मेनु', 'hi': 'मेन्यू'}),
      AppTranslation(id: '12', key: 'Nearby', category: 'Customer', translations: {'en': 'Nearby', 'ne': 'नजिकै', 'hi': 'पास में'}),
      AppTranslation(id: '13', key: 'Cart', category: 'Customer', translations: {'en': 'Cart', 'ne': 'झोला', 'hi': 'कार्ट'}),
      AppTranslation(id: '14', key: 'Profile', category: 'Customer', translations: {'en': 'Profile', 'ne': 'प्रोफाइल', 'hi': 'प्रोफ़ाइल'}),
      AppTranslation(id: '15', key: 'Rewards', category: 'Customer', translations: {'en': 'Rewards', 'ne': 'पुरस्कारहरू', 'hi': 'पुरस्कार'}),
      AppTranslation(id: '16', key: 'Explore Menu', category: 'Customer', translations: {'en': 'Explore Menu', 'ne': 'मेनु हेर्नुहोस्', 'hi': 'मेन्यू देखें'}),
      AppTranslation(id: '17', key: 'Popular Foods', category: 'Customer', translations: {'en': 'Popular Foods', 'ne': 'लोकप्रिय व्यञ्जनहरू', 'hi': 'लोकप्रिय व्यंजन'}),
      AppTranslation(id: '18', key: 'Just For You', category: 'Customer', translations: {'en': 'Just For You', 'ne': 'तपाईंको लागि मात्र', 'hi': 'केवल आपके लिए'}),
      AppTranslation(id: '19', key: 'Trending', category: 'Customer', translations: {'en': 'Trending', 'ne': 'चर्चित व्यञ्जनहरू', 'hi': 'ट्रेंडिंग'}),
      AppTranslation(id: '20', key: 'My Orders', category: 'Customer', translations: {'en': 'My Orders', 'ne': 'मेरो अर्डरहरू', 'hi': 'मेरे ऑर्डर'}),
      AppTranslation(id: '21', key: 'Table', category: 'Customer', translations: {'en': 'Table', 'ne': 'टेबल', 'hi': 'टेबल'}),
      AppTranslation(id: '22', key: 'Total Amount', category: 'Customer', translations: {'en': 'Total Amount', 'ne': 'कुल रकम', 'hi': 'कुल राशि'}),
      AppTranslation(id: '23', key: 'Checkout', category: 'Customer', translations: {'en': 'Checkout', 'ne': 'भुक्तानी', 'hi': 'चेकआउट'}),
      AppTranslation(id: '24', key: 'Add to Cart', category: 'Customer', translations: {'en': 'Add to Cart', 'ne': 'झोलामा राख्नुहोस्', 'hi': 'कार्ट में जोड़ें'}),
      AppTranslation(id: '25', key: 'Notifications', category: 'Customer', translations: {'en': 'Notifications', 'ne': 'अधिसूचनाहरू', 'hi': 'सूचनाएं'}),
      AppTranslation(id: '26', key: 'SELECT TABLE NUMBER', category: 'Customer', translations: {'en': 'SELECT TABLE NUMBER', 'ne': 'टेबल नम्बर छान्नुहोस्', 'hi': 'टेबल नंबर चुनें'}),
      AppTranslation(id: '27', key: 'TAP TO CHOOSE', category: 'Customer', translations: {'en': 'TAP TO CHOOSE', 'ne': 'थिचेर छान्नुहोस्', 'hi': 'चुनने के लिए टैप करें'}),
      AppTranslation(id: '28', key: 'Hot Deals', category: 'Customer', translations: {'en': 'Hot Deals', 'ne': 'हट डिलहरू', 'hi': 'हॉट डील्स'}),
      AppTranslation(id: '29', key: 'Delicious Fast Food', category: 'Customer', translations: {'en': 'Delicious Fast Food', 'ne': 'स्वादिष्ट फास्ट फूड', 'hi': 'स्वादिष्ट फास्ट फूड'}),
      AppTranslation(id: '30', key: 'Craving deliciousness? Enjoy hot, fresh & flavorful meals delivered fast right to your door!', category: 'Customer', translations: {'en': 'Craving deliciousness? Enjoy hot, fresh & flavorful meals delivered fast right to your door!', 'ne': 'मीठो खाने मन छ? तातो, ताजा र स्वादिष्ट खाना सिधै ढोकासम्म!', 'hi': 'स्वादिष्ट खाने की इच्छा? गर्म और ताजा खाना सीधे आपके दरवाजे पर!'}),
      AppTranslation(id: '31', key: 'Order Now', category: 'Customer', translations: {'en': 'Order Now', 'ne': 'अहिले अर्डर गर्नुहोस्', 'hi': 'अभी ऑर्डर करें'}),
      AppTranslation(id: '32', key: 'No Song Playing', category: 'Customer', translations: {'en': 'No Song Playing', 'ne': 'कुनै गीत बजेको छैन', 'hi': 'कोई गाना नहीं बज रहा है'}),
      AppTranslation(id: '33', key: 'Popular Picks', category: 'Customer', translations: {'en': 'Popular Picks', 'ne': 'लोकप्रिय रोजाइहरू', 'hi': 'लोकप्रिय विकल्प'}),
      AppTranslation(id: '34', key: 'Trending Scroll', category: 'Customer', translations: {'en': 'Trending Scroll', 'ne': 'चर्चित व्यञ्जनहरू', 'hi': 'ट्रेंडिंग व्यंजन'}),
      AppTranslation(id: '35', key: 'All Products', category: 'Customer', translations: {'en': 'All Products', 'ne': 'सबै व्यञ्जनहरू', 'hi': 'सभी उत्पाद'}),
      AppTranslation(id: '36', key: 'View All →', category: 'Customer', translations: {'en': 'View All →', 'ne': 'सबै हेर्नुहोस् →', 'hi': 'सभी देखें →'}),
      AppTranslation(id: '37', key: 'Explore →', category: 'Customer', translations: {'en': 'Explore →', 'ne': 'हेर्नुहोस् →', 'hi': 'खोजें →'}),
      AppTranslation(id: '38', key: 'More →', category: 'Customer', translations: {'en': 'More →', 'ne': 'थप →', 'hi': 'और देखें →'}),
      AppTranslation(id: '39', key: 'Explore More →', category: 'Customer', translations: {'en': 'Explore More →', 'ne': 'थप हेर्नुहोस् →', 'hi': 'और खोजें →'}),
      
      // Common Buttons
      AppTranslation(id: '100', key: 'common.add_new', category: 'Common', translations: {'en': 'Add New', 'ne': 'नयाँ थप्नुहोस्', 'hi': 'नया जोड़ें'}),
      AppTranslation(id: '101', key: 'common.save', category: 'Common', translations: {'en': 'Save', 'ne': 'सुरक्षित गर्नुहोस्', 'hi': 'सहेजें'}),
      AppTranslation(id: '102', key: 'common.update', category: 'Common', translations: {'en': 'Update', 'ne': 'अपडेट गर्नुहोस्', 'hi': 'अपडेट करें'}),
      AppTranslation(id: '103', key: 'common.delete', category: 'Common', translations: {'en': 'Delete', 'ne': 'हटाउनुहोस्', 'hi': 'हटाएं'}),
      AppTranslation(id: '104', key: 'common.cancel', category: 'Common', translations: {'en': 'Cancel', 'ne': 'रद्द गर्नुहोस्', 'hi': 'रद्द करें'}),
      AppTranslation(id: '105', key: 'common.edit', category: 'Common', translations: {'en': 'Edit', 'ne': 'सम्पादन गर्नुहोस्', 'hi': 'संपादित करें'}),
      AppTranslation(id: '106', key: 'common.close', category: 'Common', translations: {'en': 'Close', 'ne': 'बन्द गर्नुहोस्', 'hi': 'बंद करें'}),
      AppTranslation(id: '107', key: 'common.search', category: 'Common', translations: {'en': 'Search', 'ne': 'खोज्नुहोस्', 'hi': 'खोजें'}),

      // Messages
      AppTranslation(id: '200', key: 'msg.saved_success', category: 'Notifications', translations: {'en': 'Saved successfully', 'ne': 'सफलतापूर्वक सुरक्षित गरियो', 'hi': 'सफलतापूर्वक सहेजा गया'}),
      AppTranslation(id: '201', key: 'msg.updated_success', category: 'Notifications', translations: {'en': 'Updated successfully', 'ne': 'सफलतापूर्वक अपडेट गरियो', 'hi': 'सफलतापूर्वक अपडेट किया गया'}),
      AppTranslation(id: '202', key: 'msg.deleted_success', category: 'Notifications', translations: {'en': 'Deleted successfully', 'ne': 'सफलतापूर्वक हटाइयो', 'hi': 'सफलतापूर्वक हटा दिया गया'}),
      AppTranslation(id: '203', key: 'msg.no_data', category: 'Notifications', translations: {'en': 'No data found', 'ne': 'कुनै डाटा फेला परेन', 'hi': 'कोई डेटा नहीं मिला'}),
      AppTranslation(id: '204', key: 'msg.error', category: 'Notifications', translations: {'en': 'Something went wrong', 'ne': 'केही गलत भयो', 'hi': 'कुछ गलत हो गया'}),

      // Forms
      AppTranslation(id: '300', key: 'form.name', category: 'Common', translations: {'en': 'Name', 'ne': 'नाम', 'hi': 'नाम'}),
      AppTranslation(id: '301', key: 'form.status', category: 'Common', translations: {'en': 'Status', 'ne': 'अवस्था', 'hi': 'स्थिति'}),
      AppTranslation(id: '302', key: 'form.date', category: 'Common', translations: {'en': 'Date', 'ne': 'मिति', 'hi': 'तारीख'}),
      AppTranslation(id: '303', key: 'form.price', category: 'Common', translations: {'en': 'Price', 'ne': 'मूल्य', 'hi': 'मूल्य'}),
      AppTranslation(id: '304', key: 'form.description', category: 'Common', translations: {'en': 'Description', 'ne': 'विवरण', 'hi': 'विवरण'}),
      AppTranslation(id: '305', key: 'form.phone', category: 'Common', translations: {'en': 'Phone', 'ne': 'फोन', 'hi': 'फोन'}),
      AppTranslation(id: '306', key: 'form.quantity', category: 'Common', translations: {'en': 'Quantity', 'ne': 'मात्रा', 'hi': 'मात्रा'}),
      AppTranslation(id: '307', key: 'form.unit', category: 'Common', translations: {'en': 'Unit', 'ne': 'एकाइ', 'hi': 'इकाई'}),
      AppTranslation(id: '308', key: 'form.address', category: 'Common', translations: {'en': 'Address', 'ne': 'ठेगाना', 'hi': 'पता'}),
      AppTranslation(id: '309', key: 'form.email', category: 'Common', translations: {'en': 'Email', 'ne': 'इमेल', 'hi': 'ईमेल'}),

      // Validation
      AppTranslation(id: '600', key: 'val.required', category: 'Validation', translations: {'en': 'This field is required', 'ne': 'यो क्षेत्र आवश्यक छ', 'hi': 'यह फ़ील्ड आवश्यक है'}),
      AppTranslation(id: '601', key: 'val.invalid', category: 'Validation', translations: {'en': 'Invalid value', 'ne': 'अमान्य मान', 'hi': 'अमान्य मान'}),
      AppTranslation(id: '602', key: 'val.select_option', category: 'Validation', translations: {'en': 'Please select an option', 'ne': 'कृपया एउटा विकल्प छान्नुहोस्', 'hi': 'कृपया एक विकल्प चुनें'}),

      // Sub-modules
      AppTranslation(id: '700', key: 'module.unit_measurement', category: 'Inventory', translations: {'en': 'Unit Measurement', 'ne': 'एकाइ मापन', 'hi': 'इकाई माप'}),
      AppTranslation(id: '701', key: 'module.ingredients', category: 'Inventory', translations: {'en': 'Ingredients', 'ne': 'सामग्रीहरू', 'hi': 'सामग्री'}),
      AppTranslation(id: '702', key: 'module.stock', category: 'Inventory', translations: {'en': 'Stock', 'ne': 'स्टक', 'hi': 'स्टॉक'}),
      AppTranslation(id: '703', key: 'module.purchase', category: 'Purchase', translations: {'en': 'Purchase', 'ne': 'खरिद', 'hi': 'खरीद'}),

      // Sidebar Categories
      AppTranslation(id: '800', key: 'cat.manage_order', category: 'Navigation', translations: {'en': 'Manage Order', 'ne': 'अर्डर व्यवस्थापन', 'hi': 'आदेश प्रबंधित करें'}),
      AppTranslation(id: '801', key: 'cat.purchase_manage', category: 'Navigation', translations: {'en': 'Purchase Manage', 'ne': 'खरिद व्यवस्थापन', 'hi': 'खरीद प्रबंधन'}),
      AppTranslation(id: '802', key: 'cat.reservation', category: 'Navigation', translations: {'en': 'Reservation', 'ne': 'आरक्षण', 'hi': 'आरक्षण'}),
      AppTranslation(id: '803', key: 'cat.food_management', category: 'Navigation', translations: {'en': 'Food Management', 'ne': 'खाना व्यवस्थापन', 'hi': 'खाद्य प्रबंधन'}),
      AppTranslation(id: '804', key: 'cat.production', category: 'Navigation', translations: {'en': 'Production', 'ne': 'उत्पादन', 'hi': 'उत्पादन'}),
      AppTranslation(id: '805', key: 'cat.human_resource', category: 'Navigation', translations: {'en': 'Human Resource', 'ne': 'मानव संसाधन', 'hi': 'मानव संसाधन'}),
      AppTranslation(id: '806', key: 'cat.report', category: 'Navigation', translations: {'en': 'Report', 'ne': 'रिपोर्ट', 'hi': 'रिपोर्ट'}),
      AppTranslation(id: '807', key: 'cat.setting', category: 'Navigation', translations: {'en': 'Setting', 'ne': 'सेटिङ', 'hi': 'सेटिंग'}),
      AppTranslation(id: '808', key: 'nav.language', category: 'Navigation', translations: {'en': 'Language', 'ne': 'भाषा', 'hi': 'भाषा'}),

      // Dashboard
      AppTranslation(id: '400', key: 'dash.hi_admin', category: 'Dashboard', translations: {'en': 'Hi, Admin', 'ne': 'नमस्ते, एडमिन', 'hi': 'नमस्ते, एडमिन'}),
      AppTranslation(id: '401', key: 'dash.revenue_balance', category: 'Dashboard', translations: {'en': 'Revenue Balance', 'ne': 'राजस्व सन्तुलन', 'hi': 'राजस्व शेष'}),
      AppTranslation(id: '402', key: 'dash.monthly_target', category: 'Dashboard', translations: {'en': 'Monthly Target', 'ne': 'मासिक लक्ष्य', 'hi': 'मासिक लक्ष्य'}),
      AppTranslation(id: '403', key: 'dash.total_orders', category: 'Dashboard', translations: {'en': 'Total Orders', 'ne': 'कुल अर्डरहरू', 'hi': 'कुल अर्डर'}),
      AppTranslation(id: '404', key: 'dash.kitchen_alerts', category: 'Dashboard', translations: {'en': 'Kitchen Alerts', 'ne': 'भान्सा सचेतहरू', 'hi': 'रसोई अलर्ट'}),
      AppTranslation(id: '405', key: 'dash.weekly_activity', category: 'Dashboard', translations: {'en': 'Activities this week', 'ne': 'यस हप्ताका गतिविधिहरू', 'hi': 'इस सप्ताह की गतिविधियां'}),

      // POS Invoice
      AppTranslation(id: '500', key: 'pos.active_selection', category: 'Sales', translations: {'en': 'Active Selection', 'ne': 'सक्रिय चयन', 'hi': 'सक्रिय चयन'}),
      AppTranslation(id: '501', key: 'pos.select_table', category: 'Sales', translations: {'en': 'Select Room/Table', 'ne': 'कोठा/टेबल छान्नुहोस्', 'hi': 'कमरा/टेबल चुनें'}),
      AppTranslation(id: '502', key: 'pos.current_items', category: 'Sales', translations: {'en': 'Current Items', 'ne': 'वर्तमान वस्तुहरू', 'hi': 'वर्तमान वस्तुएं'}),
      AppTranslation(id: '503', key: 'pos.payment_method', category: 'Sales', translations: {'en': 'Payment Method', 'ne': 'भुक्तानी विधि', 'hi': 'भुगतान विधि'}),
      AppTranslation(id: '504', key: 'pos.subtotal', category: 'Sales', translations: {'en': 'Subtotal', 'ne': 'उप-कुल', 'hi': 'उप-कुल'}),
      AppTranslation(id: '505', key: 'pos.total_amount', category: 'Sales', translations: {'en': 'TOTAL AMOUNT', 'ne': 'कुल रकम', 'hi': 'कुल राशि'}),
      AppTranslation(id: '506', key: 'pos.generate_invoice', category: 'Sales', translations: {'en': 'GENERATE INVOICE', 'ne': 'बीजक उत्पन्न गर्नुहोस्', 'hi': 'चालान बनाएं'}),
      AppTranslation(id: '507', key: 'pos.print_kot', category: 'Sales', translations: {'en': 'PRINT KOT', 'ne': 'KOT प्रिन्ट गर्नुहोस्', 'hi': 'केओटी प्रिंट करें'}),
    ];
  }
}

// Global translation helper
String t(String key) => LanguageService().translate(key);
