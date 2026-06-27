import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/index.dart';
import '../../services/index.dart';
import '../../services/cloudinary_service.dart';
import '../../utils/index.dart';
import '../../widgets/index.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  /// Current avatar URL (from server or newly uploaded)
  String? _avatarUrl;

  /// Local file picked but not yet uploaded (preview only)
  File? _pickedImageFile;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _pickedImageFile = file;
    });

    // Upload immediately
    await _uploadAvatar(file);
  }

  /// Upload the picked file to Cloudinary, then save URL to backend DB
  Future<void> _uploadAvatar(File file) async {
    setState(() => _isUploadingAvatar = true);
    try {
      final url = await CloudinaryService().uploadImage(file, folder: 'avatars');
      // Save avatar URL to backend immediately so it persists
      await AuthService().updateProfile(avatarUrl: url);
      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _pickedImageFile = null; // Clear local preview, use network URL
          _isUploadingAvatar = false;
        });
        AppSnackbars.showSuccess(context, 'Cập nhật ảnh đại diện thành công!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        AppSnackbars.showError(context, 'Tải ảnh thất bại: $e');
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService().updateProfile(
        fullName: _nameController.text.isNotEmpty ? _nameController.text : null,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        avatarUrl: _avatarUrl,
      );

      if (mounted) {
        AppSnackbars.showSuccess(context, 'Cập nhật hồ sơ thành công!');
        Navigator.pop(context, true); // Return true to trigger reload if needed
      }
    } catch (e) {
      if (mounted) {
        AppSnackbars.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Avatar Section ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.softCard,
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingAvatar ? null : _pickImage,
                      child: Stack(
                        children: [
                          // Avatar circle
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: _buildAvatarImage(),
                            child: _buildAvatarPlaceholder(),
                          ),
                          // Upload overlay / indicator
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.surface, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _isUploadingAvatar
                                  ? const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _isUploadingAvatar
                          ? 'Đang tải lên...'
                          : 'Nhấn để thay đổi ảnh',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isUploadingAvatar
                            ? AppColors.primary
                            : AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                label: 'Họ và tên',
                hint: 'Nhập họ và tên',
                controller: _nameController,
                validator: AppValidators.validateFullName,
                prefixIcon: const Icon(Icons.person_outline_rounded,
                    color: AppColors.gray400),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Số điện thoại',
                hint: 'Nhập số điện thoại',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon:
                    const Icon(Icons.phone_outlined, color: AppColors.gray400),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              AppButton(
                label: 'Lưu thay đổi',
                isLoading: _isLoading,
                onPressed: _updateProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the avatar image provider — local file takes priority, then network
  ImageProvider? _buildAvatarImage() {
    if (_pickedImageFile != null) {
      return FileImage(_pickedImageFile!);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(_avatarUrl!);
    }
    return null;
  }

  /// Build placeholder icon when no avatar is available
  Widget? _buildAvatarPlaceholder() {
    if (_pickedImageFile != null) return null;
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) return null;
    return const Icon(Icons.person, size: 48, color: AppColors.primary);
  }
}
