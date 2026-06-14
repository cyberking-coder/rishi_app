import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import 'api_service.dart';
import 'device_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Holds session state and drives login/registration. Exposed via Provider so
/// the whole widget tree can react to sign-in / device-lock changes.
class AuthService extends ChangeNotifier {
  final ApiService api;
  final DeviceService deviceService;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kTokenKey = 'auth_token_v1';

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  AuthService({required this.api, required this.deviceService});

  /// Called on startup: restore a saved token and re-validate it (which also
  /// re-checks the device lock server-side).
  Future<void> bootstrap() async {
    final token = await _storage.read(key: _kTokenKey);
    if (token == null) {
      _setSignedOut();
      return;
    }
    api.setToken(token);
    try {
      final res = await api.get('/auth/me');
      user = AppUser.fromJson(res['user'] as Map<String, dynamic>);
      status = AuthStatus.signedIn;
    } on ApiException {
      // Token invalid or device no longer authorized → force sign-out.
      await _clearToken();
      _setSignedOut();
      return;
    }
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await api.post('/auth/register', {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
  }

  Future<void> login({required String email, required String password}) async {
    final device = await deviceService.getIdentity();
    final res = await api.post('/auth/login', {
      'email': email,
      'password': password,
      'device': device.toJson(),
    });
    final token = res['token'] as String;
    await _storage.write(key: _kTokenKey, value: token);
    api.setToken(token);
    user = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> logout() async {
    await _clearToken();
    _setSignedOut();
    notifyListeners();
  }

  Future<void> _clearToken() async {
    await _storage.delete(key: _kTokenKey);
    api.setToken(null);
  }

  void _setSignedOut() {
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
