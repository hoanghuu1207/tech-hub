import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/storage/secure_storage.dart';
import 'exceptions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio _dio;
  final SecureStorage _storage = SecureStorage();

  ApiClient._internal() {
    _initDio();
  }

  Dio get dio => _dio;

  void _initDio() {
    String baseUrl = 'http://localhost:8000/api/v1';
    try {
      baseUrl = dotenv.env['API_URL'] ?? baseUrl;
    } catch (_) {}

    // Automatically map localhost to 10.0.2.2 for Android Emulator
    try {
      if (defaultTargetPlatform == TargetPlatform.android && baseUrl.contains('localhost')) {
        baseUrl = baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    } catch (_) {}

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
    ));

    // Error and Retry Interceptor Wrapper
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // Here we can parse the standard {success, message, data, error} wrapper
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('success')) {
          if (data['success'] == false) {
            String errorMsg = data['error'] ?? 'API Error';
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: BadRequestException(errorMsg),
                type: DioExceptionType.badResponse,
              ),
            );
          }
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token expired, attempt to refresh
          final isRefreshed = await _refreshToken();
          if (isRefreshed) {
            // Retry the original request
            try {
               final token = await _storage.getToken();
               e.requestOptions.headers['Authorization'] = 'Bearer $token';
               final retryResponse = await _dio.fetch(e.requestOptions);
               return handler.resolve(retryResponse);
            } catch (retryError) {
               return handler.reject(e);
            }
          } else {
             // Logout User / Clear Data
             await _storage.deleteAll();
             return handler.reject(
               DioException(
                  requestOptions: e.requestOptions,
                  response: e.response,
                  error: UnauthorizedException('Phiên đăng nhập hết hạn.'),
                  type: DioExceptionType.badResponse,
               ),
             );
          }
        }

        // Return standardized AppExceptions based on type
        return handler.reject(_handleError(e));
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      // Note: Do not use the same _dio instance to avoid interceptor infinite loops
      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await refreshDio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newToken = response.data['data']['access_token'];
        await _storage.saveToken(newToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  DioException _handleError(DioException e) {
    AppException customException;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        customException = NetworkException('Không thể kết nối đến máy chủ.');
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        String errorMessage = 'Có lỗi xảy ra.';

        if (responseData is Map<String, dynamic> && responseData['error'] != null) {
            errorMessage = responseData['error'];
        }

        if (statusCode == 400) {
          customException = BadRequestException(errorMessage);
        } else if (statusCode == 401) {
          customException = UnauthorizedException(errorMessage);
        } else if (statusCode == 403) {
          customException = ForbiddenException(errorMessage);
        } else if (statusCode == 404) {
          customException = NotFoundException(errorMessage);
        } else if (statusCode != null && statusCode >= 500) {
          customException = ServerException('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.');
        } else {
          customException = FetchDataException('Lỗi dữ liệu hệ thống.');
        }
        break;
      default:
        customException = AppException('Đã xảy ra sự cố không xác định.');
    }

    return DioException(
      requestOptions: e.requestOptions,
      response: e.response,
      error: customException,
      type: e.type,
    );
  }
}
