import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';

/// Service to upload images to Cloudinary via the Upload API.
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  CloudinaryService._internal();
  factory CloudinaryService() => _instance;

  String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  String get _apiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  String get _apiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  /// Upload an image file to Cloudinary and return the secure URL.
  /// Uses signed upload for security.
  Future<String> uploadImage(File imageFile, {String folder = 'avatars'}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Build the string to sign (alphabetical order of params)
    final toSign = 'folder=$folder&timestamp=$timestamp$_apiSecret';
    final signature = sha1.convert(utf8.encode(toSign)).toString();

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split(Platform.pathSeparator).last,
      ),
      'api_key': _apiKey,
      'timestamp': timestamp,
      'folder': folder,
      'signature': signature,
    });

    final dio = Dio();
    final response = await dio.post(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      data: formData,
    );

    if (response.statusCode == 200 && response.data != null) {
      return response.data['secure_url'] as String;
    }

    throw Exception('Cloudinary upload failed: ${response.statusCode}');
  }
}
