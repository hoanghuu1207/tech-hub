import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  String? _baseUrl;

  String get baseUrl {
    if (_baseUrl == null) {
      try {
        _baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000/api/v1';
      } catch (e) {
        print('⚠️ dotenv not initialized, using default URL');
        _baseUrl = 'http://localhost:8000/api/v1';
      }
    }
    return _baseUrl!;
  }

  String get wsUrl => baseUrl.replaceFirst('http', 'ws');

  ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  /// Build headers with token
  Map<String, String> buildHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET request
  Future<dynamic> get(
    String endpoint, {
    String? token,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(
          queryParameters:
              queryParams?.map((k, v) => MapEntry(k, v.toString())));

      final response = await HttpClient().getUrl(uri).then((request) {
        buildHeaders(token: token).forEach((key, value) {
          request.headers.add(key, value);
        });
        return request.close();
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = await response.transform(utf8.decoder).join();
        return responseBody;
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Unauthorized');
      } else if (response.statusCode == 404) {
        throw NotFoundException('Not found');
      } else {
        throw ServerException('Server error: ${response.statusCode}');
      }
    } on SocketException {
      throw NetworkException('No internet connection');
    }
  }

  /// POST request
  Future<dynamic> post(
    String endpoint, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final request = await HttpClient().postUrl(uri);
      buildHeaders(token: token).forEach((key, value) {
        request.headers.add(key, value);
      });

      request.write(jsonEncode(body));
      final response = await request.close();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = await response.transform(utf8.decoder).join();
        return responseBody;
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Unauthorized');
      } else if (response.statusCode == 400) {
        final responseBody = await response.transform(utf8.decoder).join();
        throw BadRequestException(responseBody);
      } else {
        throw ServerException('Server error: ${response.statusCode}');
      }
    } on SocketException {
      throw NetworkException('No internet connection');
    }
  }

  /// PUT request
  Future<dynamic> put(
    String endpoint, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final request = await HttpClient().putUrl(uri);
      buildHeaders(token: token).forEach((key, value) {
        request.headers.add(key, value);
      });

      request.write(jsonEncode(body));
      final response = await request.close();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = await response.transform(utf8.decoder).join();
        return responseBody;
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Unauthorized');
      } else {
        throw ServerException('Server error: ${response.statusCode}');
      }
    } on SocketException {
      throw NetworkException('No internet connection');
    }
  }

  /// DELETE request
  Future<dynamic> delete(
    String endpoint, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final request = await HttpClient().deleteUrl(uri);
      buildHeaders(token: token).forEach((key, value) {
        request.headers.add(key, value);
      });

      final response = await request.close();

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.statusCode == 204) return null;
        final responseBody = await response.transform(utf8.decoder).join();
        return responseBody;
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Unauthorized');
      } else {
        throw ServerException('Server error: ${response.statusCode}');
      }
    } on SocketException {
      throw NetworkException('No internet connection');
    }
  }
}

// Custom exceptions
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message);
}

class BadRequestException extends ApiException {
  BadRequestException(String message) : super(message);
}

class NotFoundException extends ApiException {
  NotFoundException(String message) : super(message);
}

class ServerException extends ApiException {
  ServerException(String message) : super(message);
}
