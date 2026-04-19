import 'dart:convert';
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
