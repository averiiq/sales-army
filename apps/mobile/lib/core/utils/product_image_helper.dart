import 'package:flutter/material.dart';

import 'package:salesarmy/core/utils/app_image_helper.dart';

/// Product images are ONLY what the user uploads (camera / gallery, stored as
/// a data URI, local file or URL). No stock photos are ever substituted —
/// products without a photo show a neutral placeholder.
class ProductImageHelper {
  /// The user's uploaded image, or '' when the product has none.
  static String getImageUrl(String? imageUrl, {String? productName, String? categoryId}) =>
      (imageUrl ?? '').trim();

  static bool hasImage(String? imageUrl) => (imageUrl ?? '').trim().isNotEmpty;
}

/// Renders a product's uploaded image (data URI, local file or network URL)
/// everywhere a product appears; shows a neutral placeholder when there is no
/// image or it cannot be loaded.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    final radius = borderRadius ?? BorderRadius.circular(12);
    final iconSize = ((height ?? width ?? 44) * 0.45).clamp(14.0, 40.0).toDouble();
    final placeholder = Container(
      color: bg,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: iconSize,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
    );
    final url = ProductImageHelper.getImageUrl(imageUrl);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: bg, borderRadius: radius, border: border),
      child: ClipRRect(
        borderRadius: radius,
        child: url.isEmpty
            ? placeholder
            : AppImageHelper.buildImage(
                url,
                fit: fit,
                width: width,
                height: height,
                fallbackWidget: placeholder,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}
