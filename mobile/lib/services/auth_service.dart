import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/index.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  
  final ApiClient _apiClient = ApiClient();
  final SecureStorage _storage = SecureStorage();
  
  User? _currentUser;
  String? _token;
  bool _isAuthenticated = false;

  AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  Future<void> init() async {
    _token = await _storage.getToken();
    final userJsonStr = await _storage.getUserData();
    
    if (_token != null && userJsonStr != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(userJsonStr));
        _isAuthenticated = true;
      } catch (e) {
        // Corrupted user data
        await logout();
      }
    }
  }

  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;

  /// Check if user has a valid session.
  /// 
  /// Instead of only checking the in-memory access token (which expires in
  /// 30 min), this now reads the latest token from SecureStorage (which may
  /// have been refreshed by ApiClient interceptor) and also checks if a
  /// refresh token exists as a fallback — meaning the session can still be
  /// recovered even if the access token is expired.
  bool get isTokenValid {
    // If we still have authentication state, the session is considered valid
    // as long as a refresh token exists. The ApiClient interceptor will
    // handle transparent token refresh on actual API calls.
    if (!_isAuthenticated) return false;
    
    // Check the in-memory token first (fast path)
    if (_token != null && _isJwtNotExpired(_token!)) {
      return true;
    }
    
    // If the in-memory token is expired, we still consider the session valid
    // because the ApiClient interceptor will auto-refresh on next API call.
    // The real session expiry is determined by the refresh token (7 days).
    return _isAuthenticated;
  }

  /// Parse a JWT and check if it's not expired.
  bool _isJwtNotExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      String payload = parts[1];
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '='; break;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      
      if (data['exp'] == null) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(data['exp'] * 1000);
      return DateTime.now().isBefore(expiry);
    } catch (_) {
      return false;
    }
  }

  /// Verify authentication by attempting to refresh the token if needed.
  /// Returns true if the session is still valid.
  Future<bool> verifyAuth() async {
    if (!_isAuthenticated) return false;

    // If access token is still fresh, no need to do anything
    if (_token != null && _isJwtNotExpired(_token!)) {
      return true;
    }

    // Access token is expired — try to refresh it silently
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        // No refresh token → session truly expired
        await logout();
        return false;
      }

      // Attempt refresh
      final refreshed = await _tryRefreshToken(refreshToken);
      if (refreshed) {
        return true;
      } else {
        // Refresh token is also invalid → session expired
        await logout();
        return false;
      }
    } catch (_) {
      await logout();
      return false;
    }
  }

  /// Attempt to refresh the access token using the given refresh token.
  Future<bool> _tryRefreshToken(String refreshToken) async {
    try {
      final dio = ApiClient().dio;
      // Use a fresh Dio instance to avoid interceptor loops
      final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
      final response = await refreshDio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newToken = response.data['data']['access_token'];
        await _storage.saveToken(newToken);
        _token = newToken; // Update in-memory token
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Called by ApiClient interceptor after a successful token refresh,
  /// to keep the in-memory token in sync.
  void updateTokenInMemory(String newToken) {
    _token = newToken;
  }

  /// Register new user
  Future<User> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          if (phone != null) 'phone': phone,
          'role': 'buyer',
        },
      );

      final data = response.data['data'];
      final user = User.fromJson(data['user']);
      
      await _saveAuthData(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        user: user,
      );

      return user;
    } catch (e) {
      rethrow;
    }
  }

  /// Login
  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data['data'];
      final user = User.fromJson(data['user']);

      await _saveAuthData(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        user: user,
      );

      return user;
    } catch (e) {
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      // Call logout API to revoke token
      if (_isAuthenticated) {
        await _apiClient.dio.post('/auth/logout');
      }
    } catch (e) {
      // Ignore API error on logout (e.g. token already expired)
    } finally {
      // Always clear local data
      _isAuthenticated = false;
      _currentUser = null;
      _token = null;
      await _storage.deleteAll();
    }
  }

  /// Refetch current user Profile
  Future<User> fetchProfile() async {
    try {
      final response = await _apiClient.dio.get('/auth/me');
      final data = response.data['data'];
      final user = User.fromJson(data);
      
      _currentUser = user;
      await _storage.saveUserData(jsonEncode(user.toJson()));
      
      return user;
    } catch (e) {
      rethrow;
    }
  }

  /// Update profile
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        '/auth/me',
        data: {
          if (fullName != null) 'full_name': fullName,
          if (phone != null) 'phone': phone,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        },
      );

      final data = response.data['data'];
      final user = User.fromJson(data);
      
      _currentUser = user;
      await _storage.saveUserData(jsonEncode(user.toJson()));
      
      return user;
    } catch (e) {
      rethrow;
    }
  }

  /// Change Password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.dio.post(
        '/auth/change-password',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Save auth data to local storage
  Future<void> _saveAuthData({
    required String accessToken,
    required String refreshToken,
    required User user,
  }) async {
    await _storage.saveToken(accessToken);
    await _storage.saveRefreshToken(refreshToken);
    await _storage.saveUserData(jsonEncode(user.toJson()));
    _token = accessToken;
    _currentUser = user;
    _isAuthenticated = true;
  }
}
