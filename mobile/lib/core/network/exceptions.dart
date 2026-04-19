class AppException implements Exception {
  final String message;
  final String? prefix;

  AppException([this.message = 'Có lỗi xảy ra', this.prefix]);

  @override
  String toString() {
    return "${prefix != null ? "$prefix: " : ""}$message";
  }
}

class NetworkException extends AppException {
  NetworkException([String message = 'Không có kết nối mạng']) : super(message, 'Network Error');
}

class BadRequestException extends AppException {
  BadRequestException([String message = 'Yêu cầu không hợp lệ']) : super(message, 'Bad Request');
}

class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.']) : super(message, 'Unauthorized');
}

class ForbiddenException extends AppException {
  ForbiddenException([String message = 'Bạn không có quyền thực hiện hành động này']) : super(message, 'Forbidden');
}

class NotFoundException extends AppException {
  NotFoundException([String message = 'Không tìm thấy dữ liệu']) : super(message, 'Not Found');
}

class ServerException extends AppException {
  ServerException([String message = 'Lỗi máy chủ. Vui lòng thử lại sau.']) : super(message, 'Server Error');
}

class FetchDataException extends AppException {
  FetchDataException([String message = 'Lỗi trong quá trình giao tiếp dữ liệu']) : super(message, 'Fetch Data Error');
}
