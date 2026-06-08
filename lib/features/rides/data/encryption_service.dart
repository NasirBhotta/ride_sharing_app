import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class EncryptionService {
  static const int keySize = 32; // 256 bits for AES-256
  static const int nonceSize = 12; // 96 bits for GCM
  static const int tagSize = 16; // 128 bits for authentication tag

  /// Encrypts plaintext using AES-256-GCM
  /// Returns base64-encoded ciphertext (includes nonce + ciphertext + tag)
  String encrypt(String plaintext, Uint8List key) {
    if (key.length != keySize) {
      throw ArgumentError('Key must be $keySize bytes (256 bits)');
    }

    final random = Random.secure();
    final nonce = Uint8List(nonceSize);
    for (int i = 0; i < nonceSize; i++) {
      nonce[i] = random.nextInt(256);
    }

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true,
      AEADParameters(KeyParameter(key), tagSize * 8, nonce, Uint8List(0)),
    );

    final plaintextBytes = utf8.encode(plaintext);
    final ciphertext = cipher.process(plaintextBytes);

    // Combine: nonce (12) + ciphertext (variable) + tag (16)
    final combined = Uint8List(nonce.length + ciphertext.length);
    combined.setAll(0, nonce);
    combined.setAll(nonce.length, ciphertext);

    return base64Encode(combined);
  }

  /// Decrypts base64-encoded ciphertext using AES-256-GCM
  /// Returns plaintext string
  String decrypt(String ciphertextBase64, Uint8List key) {
    if (key.length != keySize) {
      throw ArgumentError('Key must be $keySize bytes (256 bits)');
    }

    try {
      final combined = base64Decode(ciphertextBase64);

      if (combined.length < nonceSize + tagSize) {
        throw ArgumentError('Invalid ciphertext: too short');
      }

      final nonce = combined.sublist(0, nonceSize);
      final ciphertext = combined.sublist(nonceSize);

      final cipher = GCMBlockCipher(AESEngine());
      cipher.init(
        false,
        AEADParameters(KeyParameter(key), tagSize * 8, nonce, Uint8List(0)),
      );

      final plaintext = cipher.process(ciphertext);
      return utf8.decode(plaintext);
    } catch (e) {
      throw ArgumentError('Decryption failed: $e');
    }
  }

  /// Generates a random 32-byte key suitable for AES-256
  Uint8List generateRandomKey() {
    final random = Random.secure();
    final key = Uint8List(keySize);
    for (int i = 0; i < keySize; i++) {
      key[i] = random.nextInt(256);
    }
    return key;
  }

  /// Derives a key from password using PBKDF2
  /// For now, returns a fixed-size key from password hash
  /// In production, use proper key derivation with salt
  Uint8List deriveKeyFromPassword(String password) {
    // Convert password to bytes and hash with SHA-256
    final passwordBytes = utf8.encode(password);
    final digest = SHA256Digest();
    digest.update(passwordBytes, 0, passwordBytes.length);
    final hash = Uint8List(32);
    digest.doFinal(hash, 0);
    return hash;
  }

  /// Encrypts a key using a master key (for storing ride keys in Firestore)
  /// Returns base64-encoded encrypted key
  String encryptKey(Uint8List keyToEncrypt, Uint8List masterKey) {
    return encrypt(base64Encode(keyToEncrypt), masterKey);
  }

  /// Decrypts a key encrypted with a master key
  Uint8List decryptKey(String encryptedKeyBase64, Uint8List masterKey) {
    final decrypted = decrypt(encryptedKeyBase64, masterKey);
    return base64Decode(decrypted);
  }
}
