import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  
  SecureStorage._internal();

  final _storage = const FlutterSecureStorage();

  // Keys
  static const String _keyToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUser = 'user_data';

  // Token Methods
  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  // Refresh Token Methods
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _keyRefreshToken);
  }

  // User Data Methods
  Future<void> saveUserData(String userDataJson) async {
    await _storage.write(key: _keyUser, value: userDataJson);
  }

  Future<String?> getUserData() async {
    return await _storage.read(key: _keyUser);
  }

  Future<void> deleteUserData() async {
    await _storage.delete(key: _keyUser);
  }

  // Clear everything on logout
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
