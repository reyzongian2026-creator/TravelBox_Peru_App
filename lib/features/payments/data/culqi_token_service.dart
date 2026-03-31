import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/env/app_env.dart';

/// Result of a Culqi tokenization attempt.
class CulqiTokenResult {
  final String? tokenId;
  final String? error;

  const CulqiTokenResult({this.tokenId, this.error});

  bool get success => tokenId != null && tokenId!.isNotEmpty;
}

/// Card data collected from the user for tokenization.
class CulqiCardData {
  final String cardNumber;
  final int expirationMonth;
  final int expirationYear;
  final String cvv;
  final String email;

  const CulqiCardData({
    required this.cardNumber,
    required this.expirationMonth,
    required this.expirationYear,
    required this.cvv,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'card_number': cardNumber.replaceAll(RegExp(r'\s+'), ''),
        'expiration_month': expirationMonth.toString().padLeft(2, '0'),
        'expiration_year': expirationYear.toString(),
        'cvv': cvv,
        'email': email,
      };
}

/// Service that creates Culqi tokens via direct API call using the public key.
///
/// The public key is safe to use client-side — it can only create tokens,
/// not charges. This is the standard approach recommended by Culqi for
/// mobile/desktop apps that cannot inject Culqi.js.
class CulqiTokenService {
  CulqiTokenService._();

  static final CulqiTokenService instance = CulqiTokenService._();

  static const _culqiTokenUrl = 'https://secure.culqi.com/v2/tokens';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  bool get isAvailable => AppEnv.hasCulqiConfig;

  /// Creates a Culqi token from card data.
  Future<CulqiTokenResult> createToken(CulqiCardData cardData) async {
    if (!isAvailable) {
      return const CulqiTokenResult(
        error: 'Culqi public key not configured.',
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _culqiTokenUrl,
        data: cardData.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppEnv.culqiPublicKey}',
            'Content-Type': 'application/json',
          },
        ),
      );

      final tokenId = response.data?['id']?.toString();
      if (tokenId != null && tokenId.isNotEmpty) {
        return CulqiTokenResult(tokenId: tokenId);
      }
      return const CulqiTokenResult(error: 'Token ID not found in response.');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['user_message']?.toString() ??
            data['merchant_message']?.toString() ??
            'Error al crear token Culqi.';
        return CulqiTokenResult(error: message);
      }
      return CulqiTokenResult(
        error: 'Error de conexión con Culqi: ${e.message}',
      );
    } catch (e) {
      return CulqiTokenResult(error: e.toString());
    }
  }
}
