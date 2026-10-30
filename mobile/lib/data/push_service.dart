// getToken and deleteToken still work; register() needs a device test before switching to it.
// ignore_for_file: deprecated_member_use

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config.dart';
import 'api_client.dart';

/// Android/iOS push through Firebase Cloud Messaging.
class PushService {
  PushService(this.api);
  final ApiClient api;

  static const _enabledKey = 'ghostwork_push_enabled';
  static const _storage = FlutterSecureStorage();

  static Future<bool> isEnabled() async => configuredInApp && await _storage.read(key: _enabledKey) == 'true';

  static bool get configuredInApp =>
      !kIsWeb &&
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  Future<FirebaseMessaging> _messaging() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: firebaseApiKey,
          appId: firebaseAppId,
          messagingSenderId: firebaseSenderId,
          projectId: firebaseProjectId,
        ),
      );
    }
    return FirebaseMessaging.instance;
  }

  Future<void> enable() async {
    final messaging = await _messaging();
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw ApiException(
        0,
        'Notifications are blocked for GhostWork. Allow them in your device settings.',
      );
    }
    final token = await messaging.getToken();
    if (token == null) {
      throw ApiException(0, "This device couldn't get a push address.");
    }
    await api.subscribePush(token);
    await _storage.write(key: _enabledKey, value: 'true');
  }

  Future<void> disable() async {
    final messaging = await _messaging();
    final token = await messaging.getToken();
    if (token != null) await api.unsubscribePush(token);
    await messaging.deleteToken();
    await _storage.delete(key: _enabledKey);
  }
}
