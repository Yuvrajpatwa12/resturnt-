import 'package:flutter/material.dart';
import '../cart_manager.dart';

enum AuthCardStep { emailInput, welcomeBack, thanksRegister }

class SmartAuthOverlay extends StatefulWidget {
  final bool forceShow;
  final VoidCallback? onClose;

  const SmartAuthOverlay({super.key, this.forceShow = false, this.onClose});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => const SmartAuthOverlay(forceShow: true),
    );
  }

  @override
  State<SmartAuthOverlay> createState() => _SmartAuthOverlayState();
}

class _SmartAuthOverlayState extends State<SmartAuthOverlay>
    with TickerProviderStateMixin {
  AuthCardStep _step = AuthCardStep.emailInput;
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();

  bool _isCheckingEmail = false;
  bool _isSubmittingPin = false;
  String? _errorMessage;
  Map<String, dynamic> _userMap = {};
  String _displayName = 'Diner';

  late AnimationController _badgeAnimCtrl;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _badgeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _badgeAnimCtrl, curve: Curves.easeInOut));

    // Pre-fill existing email if available
    final currentEmail = ShopManager.instance.customerEmail.value;
    if (currentEmail.isNotEmpty) {
      _emailCtrl.text = currentEmail;
    }
  }

  @override
  void dispose() {
    _badgeAnimCtrl.dispose();
    _emailCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = "Please enter a valid email address");
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _errorMessage = null;
    });

    final String derivedName = email.split('@').first;
    final res = await ShopManager.instance.syncCustomerIdentity(
      email,
      name: derivedName,
    );

    if (!mounted) return;

    if (res != null && res['status'] == 'success') {
      _userMap = Map<String, dynamic>.from(res['user'] ?? {});
      _displayName = _userMap['name'] ?? derivedName;
      if (_displayName.isEmpty || _displayName.toLowerCase() == 'guest') {
        _displayName = derivedName;
      }

      final bool hasPin =
          (res['has_pin'] == true) || (res['needs_pin'] == false);

      setState(() {
        _isCheckingEmail = false;
        _pinCtrl.clear();
        _step = hasPin ? AuthCardStep.welcomeBack : AuthCardStep.thanksRegister;
      });
    } else {
      setState(() {
        _isCheckingEmail = false;
        _errorMessage =
            res?['message'] ?? "Connection error. Please try again.";
      });
    }
  }

  Future<void> _handlePinSubmit() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 4) {
      setState(() => _errorMessage = "Please enter a 4-digit PIN");
      return;
    }

    setState(() {
      _isSubmittingPin = true;
      _errorMessage = null;
    });

    final email = _emailCtrl.text.trim();
    bool success = false;

    if (_step == AuthCardStep.welcomeBack) {
      final result = await ShopManager.instance.verifyAndLoginPin(
        email,
        pin,
        _userMap,
      );
      success = result['status'] == 'success';
      if (!success) {
        setState(() {
          _isSubmittingPin = false;
          _errorMessage =
              result['message']?.toString() ?? "Could not verify your PIN.";
        });
        return;
      }
    } else {
      success = await ShopManager.instance.registerAndSetPin(
        email,
        pin,
        _userMap,
      );
      if (!success) {
        setState(() {
          _isSubmittingPin = false;
          _errorMessage = "Failed to save PIN. Please try again.";
        });
        return;
      }
    }

    if (mounted) {
      setState(() => _isSubmittingPin = false);
      if (widget.forceShow) {
        Navigator.pop(context);
      }
      widget.onClose?.call();
    }
  }

  void _resetToEmailStep() {
    setState(() {
      _step = AuthCardStep.emailInput;
      _pinCtrl.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.forceShow) {
      return _buildOverlayWrapper(child: _buildCardContent());
    }

    return ValueListenableBuilder<bool>(
      valueListenable: ShopManager.instance.needsPin,
      builder: (context, needsPin, child) {
        if (!needsPin) return const SizedBox.shrink();
        return _buildOverlayWrapper(child: _buildCardContent());
      },
    );
  }

  Widget _buildOverlayWrapper({required Widget child}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5C00).withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.08, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(key: ValueKey(_step), child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    switch (_step) {
      case AuthCardStep.emailInput:
        return _buildEmailStepCard();
      case AuthCardStep.welcomeBack:
        return _buildWelcomeBackCard();
      case AuthCardStep.thanksRegister:
        return _buildThanksRegisterCard();
    }
  }

  // --- CARD 1: EMAIL ENTRY ---
  Widget _buildEmailStepCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 48,
            color: Color(0xFFFF5C00),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Sync Customer Profile",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter your email to sync your coins, mystery claims, and dining orders.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: Color(0xFFFF5C00),
            ),
            hintText: "your.name@gmail.com",
            labelText: "Google Email",
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF5C00), width: 2),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isCheckingEmail ? null : _handleEmailSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5C00),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFFFF5C00).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isCheckingEmail
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "CONTINUE",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
        ),
        if (widget.forceShow) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  // --- CARD 2: WELCOME BACK (EXISTING REGISTERED USER) ---
  Widget _buildWelcomeBackCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Welcome Back, $_displayName!",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _emailCtrl.text.trim(),
            style: const TextStyle(
              color: Color(0xFF047857),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Enter your 4-digit Security PIN to verify identity and restore your account.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 22,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            counterText: "",
            hintText: "••••",
            hintStyle: TextStyle(
              color: Colors.grey.shade300,
              letterSpacing: 16,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmittingPin ? null : _handlePinSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSubmittingPin
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "UNLOCK & SYNC",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _resetToEmailStep,
          child: const Text(
            "Use Different Email",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // --- CARD 3: THANKS FOR REGISTERING (NEW USER REGISTRATION) ---
  Widget _buildThanksRegisterCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5C00), Color(0xFFFF8A00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5C00).withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.celebration_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Thanks for Registering, $_displayName!",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _emailCtrl.text.trim(),
            style: const TextStyle(
              color: Color(0xFFFF5C00),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Create a 4-digit Security PIN to protect your profile, coins, and orders.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 22,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            counterText: "",
            hintText: "••••",
            hintStyle: TextStyle(
              color: Colors.grey.shade300,
              letterSpacing: 16,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFFF5C00), width: 2),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmittingPin ? null : _handlePinSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5C00),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFFFF5C00).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSubmittingPin
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "CREATE PIN & ACTIVATE",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _resetToEmailStep,
          child: const Text(
            "Use Different Email",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
