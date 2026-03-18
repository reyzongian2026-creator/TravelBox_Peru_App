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
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
  });

  final String? source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final child = _buildImage();
    if (borderRadius == null) {
      return child;
    }
    return ClipRRect(borderRadius: borderRadius!, child: child);
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
      errorBuilder: (_, _, _) => _fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return SizedBox(
          width: width,
          height: height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
    return _normalizeForAndroidEmulator(parsed).toString();
  }

  final baseUri = _normalizeForAndroidEmulator(Uri.parse(AppEnv.apiBaseUrl));
  return baseUri
      .resolve(trimmed.startsWith('/') ? trimmed : '/$trimmed')
      .toString();
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
