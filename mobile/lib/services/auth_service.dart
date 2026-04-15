import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/index.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  
  late SharedPreferences _prefs;
  String? _token;
  User? _currentUser;

  AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs.getString('auth_token');
    
    final userJson = _prefs.getString('current_user');
    if (userJson != null) {
      _currentUser = User.fromJson(jsonDecode(userJson));
    }
  }

  // Getters
  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _currentUser != null;

  /// Register new user
  Future<User> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await ApiService().post(
        '/auth/register',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
        },
      );

      final data = jsonDecode(response);
      _token = data['access_token'];
      _currentUser = User.fromJson(data['user']);

      await _saveAuthData();
      return _currentUser!;
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
      final response = await ApiService().post(
        '/auth/login',
        body: {
          'email': email,
          'password': password,
        },
      );

      final data = jsonDecode(response);
      _token = data['access_token'];
      _currentUser = User.fromJson(data['user']);

      await _saveAuthData();
      return _currentUser!;
    } catch (e) {
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _prefs.remove('auth_token');
    await _prefs.remove('current_user');
  }

  /// Refresh token
  Future<void> refreshToken() async {
    try {
      final response = await ApiService().post(
        '/auth/refresh',
        body: {},
        token: _token,
      );

      final data = jsonDecode(response);
      _token = data['access_token'];
      
      await _prefs.setString('auth_token', _token!);
    } catch (e) {
      await logout();
      rethrow;
    }
  }

  /// Verify email with OTP
  Future<void> verifyEmail({
    required String email,
    required String otp,
  }) async {
    try {
      await ApiService().post(
        '/auth/verify-email',
        body: {
          'email': email,
          'otp': otp,
        },
        token: _token,
      );

      _currentUser = _currentUser?.copyWith(isVerified: true);
      await _saveAuthData();
    } catch (e) {
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await ApiService().post(
        '/auth/forgot-password',
        body: {'email': email},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Confirm password reset
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    try {
      await ApiService().post(
        '/auth/reset-password',
        body: {
          'token': token,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Save auth data to local storage
  Future<void> _saveAuthData() async {
    await _prefs.setString('auth_token', _token ?? '');
    if (_currentUser != null) {
      await _prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
    }
  }
}
