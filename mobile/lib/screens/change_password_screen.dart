import 'package:flutter/material.dart';
import '../../services/index.dart';
import '../../utils/index.dart';
import '../../widgets/index.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService().changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        AppSnackbars.showSuccess(context, 'Đổi mật khẩu thành công!');
        Navigator.pop(context);
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
        title: const Text('Đổi mật khẩu'),
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
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Để đảm bảo tính bảo mật, vui lòng tạo mật khẩu có ít nhất 8 ký tự.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.gray600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              AppTextField(
                label: 'Mật khẩu cũ',
                hint: 'Nhập mật khẩu hiện tại',
                controller: _oldPasswordController,
                obscureText: true,
                validator: (val) {
                   if (val == null || val.isEmpty) return 'Vui lòng nhập mật khẩu cũ';
                   return null;
                },
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.gray400),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Mật khẩu mới',
                hint: 'Nhập mật khẩu mới',
                controller: _newPasswordController,
                obscureText: true,
                validator: AppValidators.validatePassword,
                prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.gray400),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Xác nhận mật khẩu mới',
                hint: 'Nhập lại mật khẩu mới',
                controller: _confirmPasswordController,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu mới';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Mật khẩu không trùng khớp';
                  }
                  return null;
                },
                prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.gray400),
              ),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              AppButton(
                label: 'Cập nhật mật khẩu',
                isLoading: _isLoading,
                onPressed: _changePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
