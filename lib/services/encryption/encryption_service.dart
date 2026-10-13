import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';

/// AES-256-GCM encryption service for face embeddings.
/// Key is stored in Android Keystore via flutter_secure_storage.
/// Embeddings are never stored in plaintext anywhere on disk.
class EncryptionService {
  final FlutterSecureStorage _secureStorage;
  final Logger _log = Logger();

  enc.Key? _cachedKey;

  EncryptionService({required FlutterSecureStorage secureStorage})
      : _secureStorage = secureStorage;

  // ─── Key Management ───────────────────────────────────────────────────────

  /// Get or generate the AES-256 key, stored in Android Keystore.
  Future<enc.Key> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    String? storedKey = await _secureStorage.read(
      key: AppConstants.keyEncryptionKey,
    );

    if (storedKey == null) {
      // Generate new 256-bit key
      final key = enc.Key.fromSecureRandom(32);
      await _secureStorage.write(
        key: AppConstants.keyEncryptionKey,
        value: base64Encode(key.bytes),
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      _cachedKey = key;
      _log.i('Generated new encryption key');
    } else {
      _cachedKey = enc.Key(base64Decode(storedKey));
    }

    return _cachedKey!;
  }

  // ─── Encrypt ──────────────────────────────────────────────────────────────

  /// Encrypt a 128-dim float embedding to a base64 string.
  /// Format: base64(iv[12] + ciphertext + tag[16])
  Future<String> encryptEmbedding(List<double> embedding) async {
    final key = await _getOrCreateKey();

    // Serialize embedding to bytes (little-endian float32)
    final byteData = ByteData(embedding.length * 4);
    for (int i = 0; i < embedding.length; i++) {
      byteData.setFloat32(i * 4, embedding[i], Endian.little);
    }
    final plaintext = byteData.buffer.asUint8List();

    // Generate random 96-bit IV for GCM
    final iv = enc.IV.fromSecureRandom(12);

    final encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.gcm),
    );

    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);

    // Combine IV + ciphertext for storage
    final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combined.setAll(0, iv.bytes);
    combined.setAll(iv.bytes.length, encrypted.bytes);

    return base64Encode(combined);
  }

  // ─── Decrypt ──────────────────────────────────────────────────────────────

  /// Decrypt a base64 ciphertext back to a float embedding.
  Future<List<double>> decryptEmbedding(String ciphertext) async {
    final key = await _getOrCreateKey();

    final combined = base64Decode(ciphertext);

    // Extract IV (first 12 bytes) and ciphertext
    final ivBytes = combined.sublist(0, 12);
    final encryptedBytes = combined.sublist(12);

    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.gcm),
    );

    final encrypted = enc.Encrypted(encryptedBytes);
    final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);

    // Deserialize float32 bytes back to doubles
    final byteData = ByteData.sublistView(Uint8List.fromList(decryptedBytes));
    final embedding = <double>[];
    for (int i = 0; i < decryptedBytes.length; i += 4) {
      embedding.add(byteData.getFloat32(i, Endian.little));
    }

    return embedding;
  }

  // ─── Batch Operations ─────────────────────────────────────────────────────

  Future<List<String>> encryptEmbeddings(List<List<double>> embeddings) async {
    final results = <String>[];
    for (final embedding in embeddings) {
      results.add(await encryptEmbedding(embedding));
    }
    return results;
  }

  Future<List<List<double>>> decryptEmbeddings(
    List<String> ciphertexts,
  ) async {
    final results = <List<double>>[];
    for (final ct in ciphertexts) {
      results.add(await decryptEmbedding(ct));
    }
    return results;
  }

  // ─── Key Rotation (re-enrollment) ────────────────────────────────────────

  /// Rotate the encryption key. All encrypted embeddings must be
  /// re-encrypted with the new key. Called at semester change.
  Future<enc.Key> rotateKey() async {
    final newKey = enc.Key.fromSecureRandom(32);
    await _secureStorage.write(
      key: AppConstants.keyEncryptionKey,
      value: base64Encode(newKey.bytes),
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    );
    _cachedKey = newKey;
    _log.i('Encryption key rotated');
    return newKey;
  }

  // ─── Secure Delete ────────────────────────────────────────────────────────

  /// Delete the encryption key — makes all stored embeddings unreadable.
  /// Called when a student requests data deletion (DPDP compliance).
  Future<void> deleteKey() async {
    await _secureStorage.delete(key: AppConstants.keyEncryptionKey);
    _cachedKey = null;
    _log.i('Encryption key deleted — all embeddings are now inaccessible');
  }
}
