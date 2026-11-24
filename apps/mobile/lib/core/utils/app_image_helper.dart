import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Structured result returned when capturing or selecting an image.
class ImagePickResult {
  final String? path;
  final String? dataUri;
  final String? error;
  final bool isCancelled;

  const ImagePickResult({
    this.path,
    this.dataUri,
    this.error,
    this.isCancelled = false,
  });

  bool get isSuccess => (path != null || dataUri != null) && error == null && !isCancelled;
  String? get durableUri => dataUri ?? path;
}

/// Centralized utility for capturing/picking images via camera or gallery,
/// and building image widgets/providers that support local device files, Base64 data URIs, and network URLs.
class AppImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Formats platform exceptions into friendly, actionable user messages.
  static String formatPickError(dynamic error, bool fromCamera) {
    final str = error.toString().toLowerCase();
    if (str.contains('camera_access_denied') ||
        str.contains('permission_denied') ||
        str.contains('permission denied') ||
        str.contains('access denied')) {
      return fromCamera
          ? 'Camera permission denied. Please allow Camera permission in device Settings.'
          : 'Photo gallery permission denied. Please allow Photos/Storage permission in device Settings.';
    }
    if (str.contains('no camera') ||
        str.contains('camera not available') ||
        str.contains('hardware') ||
        str.contains('activity not found') ||
        str.contains('no activity')) {
      return 'Camera hardware is not available on this device or emulator. Please select a photo from gallery or choose a preset.';
    }
    return 'Unable to open ${fromCamera ? 'camera' : 'photo gallery'}: $error';
  }

  /// Picks or captures an image and returns a detailed [ImagePickResult].
  /// Distinguishes between successful capture, user cancellation, and runtime/permission errors.
  static Future<ImagePickResult> pickImageWithDetails({
    required bool fromCamera,
    bool useFrontCamera = false,
    bool convertToDataUri = true,
    double maxWidth = 800,
    double maxHeight = 800,
    int imageQuality = 75,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        preferredCameraDevice: useFrontCamera ? CameraDevice.front : CameraDevice.rear,
      );

      if (file == null) {
        return const ImagePickResult(isCancelled: true);
      }

      String? dataUri;
      if (convertToDataUri) {
        try {
          final bytes = await file.readAsBytes();
          final ext = file.name.split('.').last.toLowerCase();
          final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
          dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
        } catch (e) {
          debugPrint('[AppImageHelper] Could not convert to data URI: $e');
        }
      }

      return ImagePickResult(
        path: file.path,
        dataUri: dataUri,
      );
    } catch (e) {
      final errorMsg = formatPickError(e, fromCamera);
      debugPrint('[AppImageHelper] Error picking image: $errorMsg ($e)');
      return ImagePickResult(error: errorMsg);
    }
  }

  /// Captures an image with the camera or selects one from the photo gallery.
  /// Returns the file path of the picked image, or null if cancelled or failed.
  static Future<String?> pickImage({
    required bool fromCamera,
    bool useFrontCamera = false,
    double maxWidth = 1200,
    double maxHeight = 1200,
    int imageQuality = 85,
    void Function(String error)? onError,
  }) async {
    final result = await pickImageWithDetails(
      fromCamera: fromCamera,
      useFrontCamera: useFrontCamera,
      convertToDataUri: false,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    if (result.error != null) {
      onError?.call(result.error!);
    }

    return result.path;
  }

  /// Captures an image and converts it into a self-contained Base64 data URI
  /// ensuring it never expires or disappears when the OS purges temporary cache files.
  static Future<String?> pickImageAsDataUri({
    required bool fromCamera,
    bool useFrontCamera = false,
    double maxWidth = 800,
    double maxHeight = 800,
    int imageQuality = 75,
    void Function(String error)? onError,
  }) async {
    final result = await pickImageWithDetails(
      fromCamera: fromCamera,
      useFrontCamera: useFrontCamera,
      convertToDataUri: true,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    if (result.error != null) {
      onError?.call(result.error!);
    }

    return result.durableUri;
  }

  /// Converts any temporary local file path into a durable, self-contained Data URI
  /// so it survives cache evictions and device reboots. If already a network URL or Data URI, returns as is.
  static Future<String> ensurePersistentUri(String pathOrUrl) async {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty || isDataUri(trimmed) || trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (isLocalFile(trimmed)) {
      try {
        final file = File(trimmed);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final ext = trimmed.split('.').last.toLowerCase();
          final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
          return 'data:$mime;base64,${base64Encode(bytes)}';
        }
      } catch (e) {
        debugPrint('[AppImageHelper] Error converting local file to persistent URI: $e');
      }
    }
    return trimmed;
  }

  /// Converts a local file to Base64 data URI with optional fallback.
  static Future<String?> convertFileToDataUri(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final ext = filePath.split('.').last.toLowerCase();
        final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
        return 'data:$mime;base64,${base64Encode(bytes)}';
      }
    } catch (e) {
      debugPrint('[AppImageHelper] Error reading file for data URI: $e');
    }
    return null;
  }

  /// Determines whether [pathOrUrl] points to a local file on device storage
  /// rather than an HTTP/HTTPS remote URL or web blob.
  static bool isLocalFile(String? pathOrUrl) {
    if (pathOrUrl == null) return false;
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return false;
    if (kIsWeb) return false;

    return !trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://') &&
        !trimmed.startsWith('blob:') &&
        !trimmed.startsWith('data:');
  }

  /// Determines whether [pathOrUrl] is a Base64 data URI (e.g. data:image/png;base64,...)
  static bool isDataUri(String? pathOrUrl) {
    if (pathOrUrl == null) return false;
    return pathOrUrl.trim().startsWith('data:');
  }

  /// Decodes a data URI into raw Uint8List bytes
  // Decoded images are cached so lists of products / parties don't re-decode
  // base64 (and flicker) on every rebuild.
  static final Map<int, Uint8List> _decodeCache = <int, Uint8List>{};
  static const int _decodeCacheLimit = 80;

  static Uint8List? decodeDataUri(String dataUri) {
    final key = Object.hash(dataUri.length, dataUri.hashCode);
    final hit = _decodeCache[key];
    if (hit != null) return hit;
    try {
      final commaIndex = dataUri.indexOf(',');
      final base64Str = commaIndex != -1 ? dataUri.substring(commaIndex + 1) : dataUri;
      final bytes = base64Decode(base64Str.trim());
      if (_decodeCache.length >= _decodeCacheLimit) _decodeCache.remove(_decodeCache.keys.first);
      _decodeCache[key] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('[AppImageHelper] Error decoding data URI: $e');
      return null;
    }
  }

  /// Returns an appropriate [ImageProvider] (MemoryImage, FileImage, or NetworkImage)
  /// depending on whether [pathOrUrl] is a data URI, local file, or remote web URL.
  static ImageProvider getImageProvider(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    if (isDataUri(trimmed)) {
      final bytes = decodeDataUri(trimmed);
      if (bytes != null) {
        return MemoryImage(bytes);
      }
    }
    if (isLocalFile(trimmed)) {
      return FileImage(File(trimmed));
    }
    return NetworkImage(trimmed);
  }

  /// Builds an [Image] widget that gracefully renders data URIs, local files, and network URLs
  /// with unified error and placeholder handling.
  static Widget buildImage(
    String pathOrUrl, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
    Widget? fallbackWidget,
  }) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) {
      return fallbackWidget ?? const SizedBox.shrink();
    }

    if (isDataUri(trimmed)) {
      final bytes = decodeDataUri(trimmed);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            if (errorBuilder != null) {
              return errorBuilder(context, error, stackTrace);
            }
            return fallbackWidget ?? const SizedBox.shrink();
          },
        );
      }
    }

    if (isLocalFile(trimmed)) {
      final file = File(trimmed);
      return Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          if (errorBuilder != null) {
            return errorBuilder(context, error, stackTrace);
          }
          return fallbackWidget ?? const SizedBox.shrink();
        },
      );
    }

    return Image.network(
      trimmed,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        if (errorBuilder != null) {
          return errorBuilder(context, error, stackTrace);
        }
        return fallbackWidget ?? const SizedBox.shrink();
      },
    );
  }
}
