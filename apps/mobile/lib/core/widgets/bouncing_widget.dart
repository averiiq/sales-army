import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A lightweight, tactile bouncing animation wrapper for cards, chips, and buttons.
/// Scales down smoothly to [scaleFactor] on press-down and springs back to 1.0 on release.
class BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final BorderRadius? borderRadius;
  final bool enableHaptics;

  const BouncingWidget({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.97,
    this.borderRadius,
    this.enableHaptics = true,
  });

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? widget.scaleFactor : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: _isPressed ? Curves.easeOutCubic : Curves.easeOutBack,
      child: InkWell(
        onTap: widget.onTap != null
            ? () {
                if (widget.enableHaptics) HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        onLongPress: widget.onLongPress != null
            ? () {
                if (widget.enableHaptics) HapticFeedback.mediumImpact();
                widget.onLongPress!();
              }
            : null,
        onHighlightChanged: (highlighted) {
          if (mounted) {
            setState(() => _isPressed = highlighted);
          }
        },
        borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
        child: widget.child,
      ),
    );
  }
}
