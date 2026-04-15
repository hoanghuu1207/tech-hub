import 'package:intl/intl.dart';

class AppFormatters {
  /// Format currency
  static String formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(amount);
  }

  /// Format percentage
  static String formatPercentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  /// Format date
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format date time
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  /// Format time ago
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return formatDate(dateTime);
    }
  }

  /// Format number with separator
  static String formatNumber(num value) {
    return NumberFormat('#,##0').format(value);
  }

  /// Format rating
  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }
}
