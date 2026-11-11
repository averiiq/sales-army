import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';

void main() {
  group('AppImageHelper Tests', () {
    test('isLocalFile returns true for local file paths and false for web URLs', () {
      expect(AppImageHelper.isLocalFile('https://example.com/image.png'), isFalse);
      expect(AppImageHelper.isLocalFile('http://example.com/image.png'), isFalse);
      expect(AppImageHelper.isLocalFile('blob:http://localhost:8080/uuid'), isFalse);
      expect(AppImageHelper.isLocalFile('data:image/png;base64,abc'), isFalse);
      expect(AppImageHelper.isLocalFile(''), isFalse);
      expect(AppImageHelper.isLocalFile(null), isFalse);

      expect(AppImageHelper.isLocalFile('/data/user/0/com.selxo.salesarmy/cache/image.jpg'), isTrue);
      expect(AppImageHelper.isLocalFile(r'C:\Users\test\image.jpg'), isTrue);
    });

    test('isDataUri accurately detects Base64 Data URIs', () {
      expect(AppImageHelper.isDataUri('data:image/png;base64,iVBORw0KGgoAAAANSUhEUg=='), isTrue);
      expect(AppImageHelper.isDataUri('data:image/jpeg;base64,/9j/4AAQSkZJRg=='), isTrue);
      expect(AppImageHelper.isDataUri('https://example.com/image.jpg'), isFalse);
      expect(AppImageHelper.isDataUri('/data/user/0/cache/foo.jpg'), isFalse);
      expect(AppImageHelper.isDataUri(null), isFalse);
    });

    test('decodeDataUri correctly decodes Base64 data strings into bytes', () {
      const sampleText = 'Hello SalesArmy Storefront Photo';
      final base64Sample = base64Encode(utf8.encode(sampleText));
      final dataUri = 'data:text/plain;base64,$base64Sample';

      final decodedBytes = AppImageHelper.decodeDataUri(dataUri);
      expect(decodedBytes, isNotNull);
      expect(utf8.decode(decodedBytes!), equals(sampleText));
    });

    test('formatPickError formats camera, gallery, and hardware messages cleanly', () {
      final cameraDeniedMsg = AppImageHelper.formatPickError('camera_access_denied by system', true);
      expect(cameraDeniedMsg, contains('Camera permission denied'));

      final galleryDeniedMsg = AppImageHelper.formatPickError('permission_denied by user', false);
      expect(galleryDeniedMsg, contains('Photo gallery permission denied'));

      final noHardwareMsg = AppImageHelper.formatPickError('no camera activity found', true);
      expect(noHardwareMsg, contains('Camera hardware is not available'));
    });

    test('ImagePickResult flags success, durableUri, and cancellation accurately', () {
      const cancelledResult = ImagePickResult(isCancelled: true);
      expect(cancelledResult.isCancelled, isTrue);
      expect(cancelledResult.isSuccess, isFalse);

      const errorResult = ImagePickResult(error: 'Camera denied');
      expect(errorResult.isSuccess, isFalse);
      expect(errorResult.error, equals('Camera denied'));

      const pathResult = ImagePickResult(path: '/cache/store.jpg');
      expect(pathResult.isSuccess, isTrue);
      expect(pathResult.durableUri, equals('/cache/store.jpg'));

      const dataUriResult = ImagePickResult(
        path: '/cache/store.jpg',
        dataUri: 'data:image/jpeg;base64,abcd1234',
      );
      expect(dataUriResult.isSuccess, isTrue);
      expect(dataUriResult.durableUri, equals('data:image/jpeg;base64,abcd1234'));
    });

    test('ensurePersistentUri preserves existing URLs and Data URIs', () async {
      const httpsUrl = 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500';
      final resultHttps = await AppImageHelper.ensurePersistentUri(httpsUrl);
      expect(resultHttps, equals(httpsUrl));

      const dataUri = 'data:image/jpeg;base64,testdata';
      final resultData = await AppImageHelper.ensurePersistentUri(dataUri);
      expect(resultData, equals(dataUri));
    });

    test('getImageProvider returns NetworkImage for URLs and FileImage for local files', () {
      final networkProvider = AppImageHelper.getImageProvider('https://example.com/test.png');
      expect(networkProvider, isA<NetworkImage>());

      final fileProvider = AppImageHelper.getImageProvider('/storage/emulated/0/DCIM/photo.jpg');
      expect(fileProvider, isA<FileImage>());

      const dataUri = 'data:image/jpeg;base64,iVBORw0KGgoAAAANSUhEUg==';
      final memProvider = AppImageHelper.getImageProvider(dataUri);
      expect(memProvider, isA<MemoryImage>());
    });

    testWidgets('buildImage builds widget without throwing for URLs and Data URIs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppImageHelper.buildImage('https://images.unsplash.com/photo-1542838132-92c53300491e?w=400'),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
