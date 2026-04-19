import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../services/index.dart';
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
  late TextEditingController _avatarUrlController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _avatarUrlController = TextEditingController(text: user?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService().updateProfile(
        fullName: _nameController.text.isNotEmpty ? _nameController.text : null,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        avatarUrl: _avatarUrlController.text.isNotEmpty ? _avatarUrlController.text : null,
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.softCard,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: _avatarUrlController.text.isNotEmpty
                          ? NetworkImage(_avatarUrlController.text)
                          : null,
                      child: _avatarUrlController.text.isEmpty
                          ? const Icon(Icons.person, size: 40, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Ảnh đại diện',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                label: 'Link ảnh đại diện',
                hint: 'Dán đường dẫn ảnh',
                controller: _avatarUrlController,
                prefixIcon: const Icon(Icons.image_outlined, color: AppColors.gray400),
                onChanged: (val) {
                  // Trigger rebuild to update avatar preview
                  setState((){});
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Họ và tên',
                hint: 'Nhập họ và tên',
                controller: _nameController,
                validator: AppValidators.validateFullName,
                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.gray400),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Số điện thoại',
                hint: 'Nhập số điện thoại',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.gray400),
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
}
