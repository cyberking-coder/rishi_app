import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Identity of the physical device the app is installed on.
class DeviceIdentity {
  final String id;
  final String platform; // 'android' | 'ios' | other
  final String model;
  final String osVersion;

  const DeviceIdentity({
    required this.id,
    required this.platform,
    required this.model,
    required this.osVersion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform,
        'model': model,
        'osVersion': osVersion,
      };
}

/// Produces a STABLE device fingerprint used for single-device login.
///
/// Why not the MAC / physical address? Modern iOS and Android block apps from
/// reading the real Wi-Fi MAC (iOS forbids it; Android returns a constant fake
/// value). Instead we derive an id from:
///   * a random UUID generated once and kept in the OS secure keystore, plus
///   * relatively stable hardware/OS identifiers from device_info_plus.
///
/// The UUID survives app restarts (it's in the Keychain / Android Keystore-backed
/// secure storage) but is wiped on uninstall — which is the expected behaviour for
/// a "this install on this phone" lock.
class DeviceService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kDeviceIdKey = 'device_id_v1';

  final _deviceInfo = DeviceInfoPlugin();

  Future<DeviceIdentity> getIdentity() async {
    final installId = await _getOrCreateInstallId();

    if (Platform.isAndroid) {
      final a = await _deviceInfo.androidInfo;
      final raw = '$installId|${a.id}|${a.fingerprint}|${a.model}';
      return DeviceIdentity(
        id: _hash(raw),
        platform: 'android',
        model: '${a.manufacturer} ${a.model}',
        osVersion: 'Android ${a.version.release} (SDK ${a.version.sdkInt})',
      );
    }

    if (Platform.isIOS) {
      final i = await _deviceInfo.iosInfo;
      final raw = '$installId|${i.identifierForVendor}|${i.model}';
      return DeviceIdentity(
        id: _hash(raw),
        platform: 'ios',
        model: i.utsname.machine,
        osVersion: 'iOS ${i.systemVersion}',
      );
    }

    // Fallback for any other platform (desktop/web during development).
    return DeviceIdentity(
      id: _hash(installId),
      platform: Platform.operatingSystem,
      model: 'unknown',
      osVersion: Platform.operatingSystemVersion,
    );
  }

  Future<String> _getOrCreateInstallId() async {
    var id = await _storage.read(key: _kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _storage.write(key: _kDeviceIdKey, value: id);
    }
    return id;
  }

  String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
