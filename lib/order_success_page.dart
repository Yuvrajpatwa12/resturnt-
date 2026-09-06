import 'package:flutter/material.dart';
import 'cart_manager.dart';

import 'live_order_tracking_screen.dart';

class OrderSuccessPage extends StatefulWidget {
  const OrderSuccessPage({super.key});

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  String _message = "We've started preparing your meal.\nSit back and relax!";
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

    // After animation, place order and navigate automatically
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;

      await ShopManager.instance.placeOrder(); 
      final int? orderId = ShopManager.instance.activeOrderId.value;
      
      if (mounted) {
        if (orderId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LiveOrderTrackingScreen(orderId: orderId)),
          );
        } else {
          // If ID is null, order failed to save in DB
          setState(() {
            _isError = true;
            _message = "Database Error: Could not save order.\nPlease contact staff or try again.";
          });
        }
      }
    });
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
                  color: _isError ? Colors.red : const Color(0xFF00B365),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isError ? Icons.error_outline : Icons.check,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _isError ? "Order Failed" : "Order Confirmed!",
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
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
            const Spacer(flex: 2),
            if (!_isError) ...[
              const CircularProgressIndicator(color: Color(0xFFFF5C00), strokeWidth: 2),
              const SizedBox(height: 12),
              const Text("Redirecting to your orders...", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Go Back to Cart", style: TextStyle(fontWeight: FontWeight.bold)),
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
