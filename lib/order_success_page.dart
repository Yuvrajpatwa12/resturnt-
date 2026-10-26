import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'services/notification_sound_stub.dart'
    if (dart.library.js_interop) 'services/notification_sound_web.dart'
    as notification_sound;

import 'live_order_tracking_screen.dart';

class OrderSuccessPage extends StatefulWidget {
  const OrderSuccessPage({super.key});

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  String _message = "Please wait while we save your order.";
  bool _isLoading = true;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();

    _saveOrderAndContinue();
  }

  Future<void> _saveOrderAndContinue() async {
    await ShopManager.instance.placeOrder();
    final int? orderId = ShopManager.instance.activeOrderId.value;
    if (!mounted) return;

    if (orderId == null) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _message =
            "Could not confirm that your order was saved.\nPlease try again or contact staff.";
      });
      return;
    }

    notification_sound.playNotificationSound('order_success');
    setState(() {
      _isLoading = false;
      _message = "Your order was saved successfully.";
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LiveOrderTrackingScreen(orderId: orderId),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isLoading
                      ? Colors.orange
                      : _isError
                      ? Colors.red
                      : const Color(0xFF00B365),
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(
                        _isError ? Icons.error_outline : Icons.check,
                        color: Colors.white,
                        size: 60,
                      ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _isLoading
                  ? "Saving your order..."
                  : _isError
                  ? "Order Failed"
                  : "Order Confirmed!",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const Spacer(flex: 2),
            if (_isLoading) ...[
              const Text(
                "Waiting for database confirmation...",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ] else if (!_isError) ...[
              const CircularProgressIndicator(
                color: Color(0xFFFF5C00),
                strokeWidth: 2,
              ),
              const SizedBox(height: 12),
              const Text(
                "Redirecting to your orders...",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Go Back to Cart",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
