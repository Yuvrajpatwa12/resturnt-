import 'package:flutter/material.dart';
import 'api_service.dart';

class CurrencyService extends ChangeNotifier {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  final ValueNotifier<String> currentCurrencyCode = ValueNotifier<String>(
    'NPR',
  );
  final ValueNotifier<String> currentCurrencySymbol = ValueNotifier<String>(
    'Rs.',
  );
  bool _isInitialized = false;

  static const List<Map<String, String>> availableCurrencies = [
    {
      'code': 'NPR',
      'symbol': 'Rs.',
      'name': 'Nepalese Rupee',
      'country': 'Nepal',
      'flag': '🇳🇵',
    },
    {
      'code': 'INR',
      'symbol': '₹',
      'name': 'Indian Rupee',
      'country': 'India',
      'flag': '🇮🇳',
    },
    {
      'code': 'USD',
      'symbol': '\$',
      'name': 'United States Dollar',
      'country': 'United States',
      'flag': '🇺🇸',
    },
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    notifyListeners();
  }

  void applyTenantCurrency(String code, String symbol) {
    if (code.isNotEmpty) {
      currentCurrencyCode.value = code;
    }
    if (symbol.isNotEmpty) {
      currentCurrencySymbol.value = symbol;
    } else {
      // Fallback symbol lookup
      final match = availableCurrencies.firstWhere(
        (c) => c['code'] == code,
        orElse: () => {'symbol': 'Rs.'},
      );
      currentCurrencySymbol.value = match['symbol']!;
    }
    notifyListeners();
  }

  Future<void> setCurrency(
    String code,
    String symbol, {
    String? tenantId,
  }) async {
    currentCurrencyCode.value = code;
    currentCurrencySymbol.value = symbol;

    if (tenantId != null && tenantId.isNotEmpty) {
      await ApiService.updateTenantCurrency(tenantId, code, symbol);
    }
    notifyListeners();
  }

  String formatPrice(dynamic amount) {
    if (amount == null) return "${currentCurrencySymbol.value} 0";
    String str = amount
        .toString()
        .replaceAll('NPR', '')
        .replaceAll('Rs.', '')
        .replaceAll('\$', '')
        .replaceAll('₹', '')
        .trim();
    if (str.isEmpty || str == '0' || str == '0.00' || str == 'Coming Soon') {
      return str;
    }
    return "${currentCurrencySymbol.value} $str";
  }

  String get currencySymbol => currentCurrencySymbol.value;
  String get currencyCode => currentCurrencyCode.value;
}
