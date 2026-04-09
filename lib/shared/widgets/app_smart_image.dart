import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/env/app_env.dart';

class AppSmartImage extends StatelessWidget {
  const AppSmartImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
  });

  final String? source;
  final double? width;
  final double? height;
  final double? aspectRatio;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    Widget child = _buildImage();
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    if (aspectRatio != null) {
      child = AspectRatio(aspectRatio: aspectRatio!, child: child);
    }
    return child;
  }

  Widget _buildImage() {
    final trimmed = source?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _fallback();
    }
    if (_isSvgDataUrl(trimmed)) {
      return _fallback();
    }

    final memoryBytes = _decodeRasterDataUrl(trimmed);
    if (memoryBytes != null) {
      return Image.memory(
        memoryBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    final resolvedUrl = resolveAppMediaUrl(trimmed);
    if (resolvedUrl == null) {
      return _fallback();
    }

    return Image.network(
      resolvedUrl,
      width: width,
      height: height,
      fit: fit,
      cacheHeight: height != null && height!.isFinite
          ? (height! * 2).toInt()
          : null,
      cacheWidth: width != null && width!.isFinite
          ? (width! * 2).toInt()
          : null,
      errorBuilder: (_, error, stackTrace) {
        return _fallbackWithDebug(resolvedUrl, error);
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: child,
          );
        }
        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _fallback() {
    if (fallback != null) {
      return fallback!;
    }
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFE5EEF1),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }

  Widget _fallbackWithDebug(String url, Object? error) {
    if (fallback != null) {
      return fallback!;
    }
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFE5EEF1),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 20),
          if (kDebugMode && url.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                url.length > 30 ? '${url.substring(0, 30)}...' : url,
                style: const TextStyle(fontSize: 8),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

String? resolveAppMediaUrl(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('data:')) {
    return trimmed;
  }
  if (_isLikelyLocalPath(trimmed)) {
    return null;
  }
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme) {
    final proxiedAzureUrl = _tryMapAzureBlobUrlToBackendProxy(parsed);
    if (proxiedAzureUrl != null) {
      return _normalizeForAndroidEmulator(proxiedAzureUrl).toString();
    }
    return _normalizeForAndroidEmulator(parsed).toString();
  }

  final baseUri = _normalizeForAndroidEmulator(
    Uri.parse(AppEnv.resolvedApiBaseUrl),
  );
  return baseUri
      .resolve(trimmed.startsWith('/') ? trimmed : '/$trimmed')
      .toString();
}

bool isGeneratedWarehouseImageUrl(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return false;
  }

  final parsed = Uri.tryParse(trimmed);
  final path = (parsed?.path ?? trimmed).trim().toLowerCase();
  return RegExp(r'^/api/v1/warehouses/\d+/image$').hasMatch(path);
}

bool _isSvgDataUrl(String value) {
  return value.startsWith('data:image/svg+xml');
}

Uint8List? _decodeRasterDataUrl(String value) {
  final match = RegExp(
    r'^data:image\/(?:png|jpeg|jpg|webp|gif);base64,(.+)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  try {
    return base64Decode(match.group(1)!);
  } catch (_) {
    return null;
  }
}

bool _isLikelyLocalPath(String value) {
  return RegExp(r'^[a-zA-Z]:\\').hasMatch(value);
}

Uri _normalizeForAndroidEmulator(Uri input) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return input;
  }
  final host = input.host.trim().toLowerCase();
  if (host != 'localhost' && host != '127.0.0.1') {
    return input;
  }
  return input.replace(host: '10.0.2.2');
}

Uri? _tryMapAzureBlobUrlToBackendProxy(Uri uri) {
  final host = uri.host.trim().toLowerCase();
  if (!host.endsWith('.blob.core.windows.net')) {
    return null;
  }

  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length < 2) {
    return null;
  }

  final container = segments.first.trim().toLowerCase();
  final filename = segments.last.trim();
  if (filename.isEmpty) {
    return null;
  }

  final category = switch (container) {
    'travelbox-profiles' => 'profiles',
    'travelbox-warehouses' => 'warehouses',
    'travelbox-documents' => 'documents',
    'travelbox-evidences' => 'evidences',
    'travelbox-images' => 'images',
    'travelbox-reports' => 'reports',
    'travelbox-exports' => 'exports',
    _ => null,
  };
  if (category == null) {
    return null;
  }

  final baseUri = _normalizeForAndroidEmulator(
    Uri.parse(AppEnv.resolvedApiBaseUrl),
  );
  return baseUri.resolve('/api/v1/files/$category/$filename');
}
