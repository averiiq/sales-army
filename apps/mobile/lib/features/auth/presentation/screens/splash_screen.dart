import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Minimal, Elegant, and Professional Enterprise Splash Screen for SalesArmy
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _timer;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    // Auto proceed smoothly
    _timer = Timer(const Duration(milliseconds: 1800), _finish);
  }

  void _finish() {
    if (_isFinished || !mounted) return;
    _isFinished = true;
    _timer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return GestureDetector(
      onTap: _finish,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 3),

                        // Minimal, Clean Logo Container
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Image.asset(
                            'assets/SalesArmy Logo 2.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.business_center_rounded,
                              size: 40,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Brand Wordmark
                        Text(
                          'SalesArmy',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Brand Motto
                        const Text(
                          'SALES TODAY  •  STRONGER TOMORROW',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Color(0xFFD97706),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Clean Minimal Tagline
                        Text(
                          'Smart FMCG & Distributor Operations Suite',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                            letterSpacing: 0.1,
                          ),
                        ),

                        const Spacer(flex: 3),

                        // Minimalist Progress Indicator
                        SizedBox(
                          width: 60,
                          height: 2.5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: const LinearProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                              backgroundColor: Color(0xFFF1F5F9),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Subtle Version Tag
                        Text(
                          'Enterprise Edition • v2.4.1',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            letterSpacing: 0.3,
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
