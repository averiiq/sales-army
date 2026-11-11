import 'package:flutter/material.dart';

class ProductImageHelper {
  /// Returns a high-resolution, clean FMCG product image URL based on product name / category.
  static String getImageUrl(String? imageUrl, {String? productName, String? categoryId}) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return imageUrl.trim();
    }

    final name = (productName ?? '').toLowerCase();
    final cat = (categoryId ?? '').toLowerCase();

    if (name.contains('atta') || name.contains('wheat') || name.contains('flour')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('cleaner') || name.contains('surface') || name.contains('disinfectant')) {
      return 'https://images.unsplash.com/photo-1585421514738-01798e348b17?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('toilet') || name.contains('harpic')) {
      return 'https://images.unsplash.com/photo-1584813470613-5b1c1cad3d69?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('glass') || name.contains('spray') || name.contains('colin')) {
      return 'https://images.unsplash.com/photo-1585421514284-efb74c2b69ba?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('milk') || name.contains('taaza') || cat.contains('dairy')) {
      return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('butter') || name.contains('ghee')) {
      return 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('parle') || name.contains('biscuit') || name.contains('good day') || name.contains('oreo') || cat.contains('bakery')) {
      return 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('tea') || name.contains('coffee') || name.contains('red label') || name.contains('nescafe')) {
      return 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('oil') || name.contains('sunlite') || name.contains('saffola') || cat.contains('oil')) {
      return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('handwash') || name.contains('dettol')) {
      return 'https://images.unsplash.com/photo-1608248597359-59752174c3d8?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('vim') || name.contains('dishwash')) {
      return 'https://images.unsplash.com/photo-1583947215259-38e31be8751f?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('surf') || name.contains('ariel') || name.contains('detergent')) {
      return 'https://images.unsplash.com/photo-1610557892470-55d9e80c0bce?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('maggi') || name.contains('noodle')) {
      return 'https://images.unsplash.com/photo-1612927601601-6638404737ce?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('ketchup') || name.contains('sauce')) {
      return 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('chilli') || name.contains('turmeric') || name.contains('haldi') || name.contains('spice') || name.contains('powder')) {
      return 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('salt')) {
      return 'https://images.unsplash.com/photo-1626197031507-c17099753214?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('rice') || name.contains('basmati')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('chocolate') || name.contains('silk') || name.contains('cadbury')) {
      return 'https://images.unsplash.com/photo-1549007994-cb92caebd54b?auto=format&fit=crop&w=400&q=80';
    } else if (name.contains('bhujia') || name.contains('namkeen') || name.contains('snack') || cat.contains('snack')) {
      return 'https://images.unsplash.com/photo-1621996346565-e3d5d6281699?auto=format&fit=crop&w=400&q=80';
    }

    return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80';
  }

  /// Returns a category emoji for visual fallback.
  static String getEmoji({String? productName, String? categoryId}) {
    final name = (productName ?? '').toLowerCase();
    final cat = (categoryId ?? '').toLowerCase();

    if (name.contains('atta') || name.contains('wheat') || name.contains('flour') || cat.contains('grocer') || name.contains('rice')) {
      return '🌾';
    } else if (name.contains('cleaner') || name.contains('harpic') || name.contains('lizol') || name.contains('vim')) {
      return '🧴';
    } else if (name.contains('toilet')) {
      return '🚽';
    } else if (name.contains('glass') || name.contains('spray') || name.contains('colin')) {
      return '✨';
    } else if (name.contains('oil') || name.contains('sunlite') || name.contains('saffola')) {
      return '🌻';
    } else if (name.contains('milk') || name.contains('dairy')) {
      return '🥛';
    } else if (name.contains('butter') || name.contains('ghee')) {
      return '🧈';
    } else if (name.contains('biscuit') || name.contains('parle') || name.contains('good day') || name.contains('oreo') || cat.contains('bakery')) {
      return '🍪';
    } else if (name.contains('tea') || name.contains('coffee')) {
      return '🫖';
    } else if (name.contains('chilli') || name.contains('turmeric') || name.contains('spice')) {
      return '🌶️';
    } else if (name.contains('bhujia') || name.contains('snack') || name.contains('silk') || name.contains('namkeen')) {
      return '🥨';
    }
    return '📦';
  }

  /// Returns a soft pastel background color for fallback.
  static Color getBackgroundColor({String? productName, String? categoryId}) {
    final name = (productName ?? '').toLowerCase();
    final cat = (categoryId ?? '').toLowerCase();

    if (name.contains('atta') || name.contains('wheat') || name.contains('flour') || cat.contains('grocer')) {
      return const Color(0xFFFEF3C7);
    } else if (name.contains('cleaner') || name.contains('surface') || name.contains('harpic')) {
      return const Color(0xFFE0F2FE);
    } else if (name.contains('toilet')) {
      return const Color(0xFFE0E7FF);
    } else if (name.contains('glass') || name.contains('spray')) {
      return const Color(0xFFEDE9FE);
    } else if (name.contains('oil') || name.contains('sunlite') || name.contains('saffola')) {
      return const Color(0xFFFEF9C3);
    } else if (name.contains('milk') || name.contains('dairy')) {
      return const Color(0xFFDBEAFE);
    } else if (name.contains('butter') || name.contains('ghee')) {
      return const Color(0xFFFEF3C7);
    } else if (name.contains('biscuit') || name.contains('parle') || cat.contains('bakery')) {
      return const Color(0xFFFFEDD5);
    } else if (name.contains('bhujia') || name.contains('snack') || name.contains('silk')) {
      return const Color(0xFFFCE7F3);
    }
    return const Color(0xFFF1F5F9);
  }
}

/// A robust, beautiful Product Image widget that gracefully renders network photos
/// with smooth loading indicators and elegant pastel category fallbacks on network error or offline.
class ProductImageView extends StatelessWidget {
  final String? imageUrl;
  final String? productName;
  final String? categoryId;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Color? backgroundColor;
  final Border? border;

  const ProductImageView({
    super.key,
    this.imageUrl,
    this.productName,
    this.categoryId,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.contain,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = ProductImageHelper.getImageUrl(
      imageUrl,
      productName: productName,
      categoryId: categoryId,
    );
    final fallbackColor = backgroundColor ??
        ProductImageHelper.getBackgroundColor(
          productName: productName,
          categoryId: categoryId,
        );
    final emoji = ProductImageHelper.getEmoji(
      productName: productName,
      categoryId: categoryId,
    );
    final radius = borderRadius ?? BorderRadius.circular(12);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: radius,
        border: border,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.network(
          effectiveUrl,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: fallbackColor,
              alignment: Alignment.center,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF94A3B8).withValues(alpha: 0.6),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // Elegant pastel emoji fallback when offline or in test environments
            return Container(
              color: fallbackColor,
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: (height != null ? height! * 0.45 : 22).clamp(16, 42).toDouble(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
