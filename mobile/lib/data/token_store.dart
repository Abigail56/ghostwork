import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the long-lived refresh token is kept. Access tokens stay in memory only.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();

  /// Keychain (iOS) / Keystore-backed storage (Android). On web the token is kept in
  /// memory only, so a browser never persists a long-lived refresh token.
  factory TokenStore.platform() => kIsWeb ? MemoryTokenStore() : SecureTokenStore();
}

class SecureTokenStore implements TokenStore {
  static const _key = 'ghostwork_refresh_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
