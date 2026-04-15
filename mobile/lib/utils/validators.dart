import 'package:flutter/material.dart';

class AppValidators {
  /// Validate email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email không được để trống';
    }

    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value)) {
      return 'Email không hợp lệ';
    }

    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mật khẩu không được để trống';
    }

    if (value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }

    return null;
  }

  /// Validate full name
  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Tên đầy đủ không được để trống';
    }

    if (value.length < 2) {
      return 'Tên phải có ít nhất 2 ký tự';
    }

    return null;
  }

  /// Validate phone
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Số điện thoại không được để trống';
    }

    final regex = RegExp(r'^0[0-9]{9}$');
    if (!regex.hasMatch(value)) {
      return 'Số điện thoại không hợp lệ';
    }

    return null;
  }

  /// Validate address
  static String? validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Địa chỉ không được để trống';
    }

    if (value.length < 5) {
      return 'Địa chỉ phải có ít nhất 5 ký tự';
    }

    return null;
  }
}
