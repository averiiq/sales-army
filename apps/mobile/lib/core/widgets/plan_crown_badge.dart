import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';

/// Small crown (no text) marking which plan a feature belongs to — like the
/// Pro crowns in Canva. The colour is the CHEAPEST active plan whose
/// admin-configured capabilities include [feature]:
///   Enterprise = gold, Grow = purple, Startup = green.
/// Plans with other ids are coloured by price rank (cheapest green, most
/// expensive gold, others purple). Renders nothing if no plan has the feature.
///
/// Once the agency's own (unexpired) plan includes the feature, the crown is
/// shown faded — it is unlocked. If the plan ends (read-only), it is bright
/// again as a reminder to renew.
class PlanCrownBadge extends StatelessWidget {
  final String feature;
  final double size;

  const PlanCrownBadge({super.key, required this.feature, this.size = 16});

  static const Color gold = Color(0xFFF59E0B);
  static const Color goldDeep = Color(0xFFB45309);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleDeep = Color(0xFF5B21B6);
  static const Color green = Color(0xFF16A34A);
  static const Color greenDeep = Color(0xFF166534);

  /// Opacity of the crown when the feature is already unlocked.
  static const double unlockedOpacity = 0.35;

  /// Cheapest active plan that includes [feature], or null.
  static SubscriptionPlanModel? lowestPlanFor(
    List<SubscriptionPlanModel> plans,
    String feature,
  ) {
    final key = AppState.canonicalFeature(feature);
    final having =
        plans
            .where((p) => p.isActive && p.allowedFeatures.contains(key))
            .toList()
          ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
    return having.isEmpty ? null : having.first;
  }

  /// (light, dark) crown colours for [plan].
  static (Color, Color) colorsFor(
    SubscriptionPlanModel plan,
    List<SubscriptionPlanModel> plans,
  ) {
    final id = plan.id.toLowerCase();
    if (id.contains('enterprise') || id.contains('platinum'))
      return (gold, goldDeep);
    if (id.contains('grow') || id.contains('gold')) return (purple, purpleDeep);
    if (id.contains('startup') ||
        id.contains('starter') ||
        id.contains('silver'))
      return (green, greenDeep);
    final active = plans.where((p) => p.isActive).toList()
      ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
    final rank = active.indexWhere((p) => p.id == plan.id);
    if (rank <= 0) return (green, greenDeep);
    if (rank >= active.length - 1) return (gold, goldDeep);
    return (purple, purpleDeep);
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.select<AppState, List<SubscriptionPlanModel>>(
      (s) => s.subscriptionPlans,
    );
    final unlocked = context.select<AppState, bool>(
      (s) => s.hasFeature(feature) && !s.isReadOnlyMode,
    );
    final plan = lowestPlanFor(plans, feature);
    if (plan == null) return const SizedBox.shrink();
    final (light, deep) = colorsFor(plan, plans);
    return Tooltip(
      message: unlocked ? 'Included in your plan' : '${plan.name} plan',
      child: AnimatedOpacity(
        key: ValueKey('crown-${unlocked ? 'unlocked' : 'locked'}-$feature'),
        opacity: unlocked ? unlockedOpacity : 1,
        duration: const Duration(milliseconds: 250),
        child: Container(
          width: size + 6,
          height: size + 6,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [light, deep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: unlocked
                ? const []
                : [
                    BoxShadow(
                      color: deep.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: CustomPaint(painter: _CrownPainter()),
        ),
      ),
    );
  }
}

/// A simple three-point crown, drawn so it stays crisp at any size.
class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final crown = Path()
      ..moveTo(w * 0.08, h * 0.30)
      ..lineTo(w * 0.30, h * 0.55)
      ..lineTo(w * 0.50, h * 0.18)
      ..lineTo(w * 0.70, h * 0.55)
      ..lineTo(w * 0.92, h * 0.30)
      ..lineTo(w * 0.82, h * 0.78)
      ..lineTo(w * 0.18, h * 0.78)
      ..close();
    canvas.drawPath(crown, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.83, w * 0.64, h * 0.10),
        Radius.circular(h * 0.05),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
