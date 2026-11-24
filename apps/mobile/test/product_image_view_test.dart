import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/utils/product_image_helper.dart';

// 1x1 transparent PNG
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

void main() {
  testWidgets('uploaded (data URI) product image is rendered from memory', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ProductImageView(imageUrl: _png, width: 60, height: 60))));
    expect(find.byType(Image), findsOneWidget);
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<MemoryImage>());
  });

  testWidgets('no image -> neutral placeholder, never a stock photo', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProductImageView(imageUrl: null, productName: 'Aashirvaad Atta', width: 60, height: 60)),
    ));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(ProductImageHelper.getImageUrl(null, productName: 'Aashirvaad Atta'), isEmpty);
  });
}
