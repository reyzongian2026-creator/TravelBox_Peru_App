import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _accessTokenKey = 'travelbox.session.access_token.v1';
const _refreshTokenKey = 'travelbox.session.refresh_token.v1';

abstract class SessionTokenStorage {
  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<void> writeTokens({
    required String? accessToken,
    required String? refreshToken,
  });

  Future<void> clearTokens();
}

class SecureSessionTokenStorage implements SessionTokenStorage {
  SecureSessionTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> writeTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    final normalizedAccessToken = accessToken?.trim() ?? '';
    final normalizedRefreshToken = refreshToken?.trim() ?? '';

    if (normalizedAccessToken.isEmpty) {
      await _storage.delete(key: _accessTokenKey);
    } else {
      await _storage.write(key: _accessTokenKey, value: normalizedAccessToken);
    }

    if (normalizedRefreshToken.isEmpty) {
      await _storage.delete(key: _refreshTokenKey);
    } else {
      await _storage.write(
        key: _refreshTokenKey,
        value: normalizedRefreshToken,
      );
    }
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
