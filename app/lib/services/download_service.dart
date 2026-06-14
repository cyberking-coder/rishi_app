import 'dart:io';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';

/// Downloads media and stores it **encrypted inside the app's private sandbox**.
///
/// Key properties:
///   * Files go under `getApplicationSupportDirectory()` — the app's private area,
///     not the gallery, Downloads folder, or any path visible to other apps or a
///     file manager. On uninstall they're removed with the app.
///   * Bytes are AES-encrypted with a per-install key kept in the OS secure
///     keystore, so even a rooted file pull yields ciphertext, not playable media.
///   * To play, we decrypt to a short-lived file in the (also private) cache dir
///     and delete it afterwards.
///
/// This stops casual extraction and sharing. Defeating screen-recording or a
/// fully rooted attacker requires commercial DRM (Widevine/FairPlay), a planned
/// follow-up.
class DownloadService {
  final ApiService api;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kKeyName = 'media_aes_key_v1';

  DownloadService(this.api);

  Future<Directory> _vaultDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/media_vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(int mediaId) async {
    final dir = await _vaultDir();
    return File('${dir.path}/$mediaId.enc');
  }

  Future<bool> isDownloaded(int mediaId) async =>
      (await _fileFor(mediaId)).exists();

  Future<enc.Key> _getOrCreateKey() async {
    var b64 = await _storage.read(key: _kKeyName);
    if (b64 == null) {
      final key = enc.Key.fromSecureRandom(32); // AES-256
      b64 = key.base64;
      await _storage.write(key: _kKeyName, value: b64);
    }
    return enc.Key.fromBase64(b64);
  }

  /// Fetch from the server, encrypt, and persist into the vault.
  Future<void> download(int mediaId) async {
    final bytes = await api.getBytes('/media/$mediaId/download');
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final cipher = encrypter.encryptBytes(bytes, iv: iv);

    // Layout: [16-byte IV][ciphertext]
    final out = await _fileFor(mediaId);
    await out.writeAsBytes([...iv.bytes, ...cipher.bytes], flush: true);
  }

  /// Decrypt a downloaded item to a temporary private file for playback.
  /// Caller is responsible for deleting it when playback ends.
  Future<File> openForPlayback(int mediaId) async {
    final src = await _fileFor(mediaId);
    if (!await src.exists()) {
      throw StateError('Media $mediaId is not downloaded');
    }
    final raw = await src.readAsBytes();
    final iv = enc.IV(raw.sublist(0, 16));
    final cipher = enc.Encrypted(raw.sublist(16));
    final key = await _getOrCreateKey();
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final plain = encrypter.decryptBytes(cipher, iv: iv);

    final cache = await getTemporaryDirectory();
    final tmp = File('${cache.path}/play_$mediaId.tmp');
    await tmp.writeAsBytes(plain, flush: true);
    return tmp;
  }

  Future<void> delete(int mediaId) async {
    final f = await _fileFor(mediaId);
    if (await f.exists()) await f.delete();
  }
}
