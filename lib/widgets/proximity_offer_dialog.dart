import 'package:flutter/material.dart';

class ProximityOfferDialog extends StatelessWidget {
  final VoidCallback onDismiss;
  final String restaurantName;

  const ProximityOfferDialog({
    super.key, 
    required this.onDismiss,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Icon or Image
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome, 
                  color: Color(0xFFFF5C00), 
                  size: 40
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Welcome Back to $restaurantName!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "We noticed you're nearby! Since you're a valued regular, here is a secret treat for today.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey, 
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: const [
                    Text(
                      "YOUR SPECIAL OFFER",
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.w900, 
                        color: Color(0xFFFF5C00),
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Free Extra Toppings",
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "CLAIM & ENTER SHOP",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                child: const Text(
                  "Dismiss", 
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
