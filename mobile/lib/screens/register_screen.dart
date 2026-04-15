import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/index.dart';
import '../../utils/index.dart';
import '../../widgets/index.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Text(
                      'Tạo Tài Khoản',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Đăng ký để bắt đầu mua sắm',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.gray600,
                  ),
                ),
                const SizedBox(height: 30),
                AppTextField(
                  label: 'Họ và tên',
                  hint: 'Nhập họ và tên của bạn',
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  validator: AppValidators.validateFullName,
                  prefixIcon: const Icon(Icons.person_outlined),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Email',
                  hint: 'Nhập email của bạn',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.validateEmail,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Mật khẩu',
                  hint: 'Ít nhất 6 ký tự',
                  controller: _passwordController,
                  validator: AppValidators.validatePassword,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outlined),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Xác nhận mật khẩu',
                  hint: 'Nhập lại mật khẩu',
                  controller: _confirmPasswordController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng xác nhận mật khẩu';
                    }
                    if (value != _passwordController.text) {
                      return 'Mật khẩu không trùng khớp';
                    }
                    return null;
                  },
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outlined),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _agreeToTerms = !_agreeToTerms;
                          });
                        },
                        child: const Text(
                          'Tôi đồng ý với Điều khoản dịch vụ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gray600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is AuthSuccess) {
                      AppSnackbars.showSuccess(context, 'Đăng ký thành công!');
                      Navigator.of(context).pushReplacementNamed('/home');
                    } else if (state is AuthFailure) {
                      AppSnackbars.showError(context, state.message);
                    }
                  },
                  builder: (context, state) => AppButton(
                      label: 'Đăng Ký',
                      onPressed: () {
                        if (_agreeToTerms && _formKey.currentState!.validate()) {
                          context.read<AuthBloc>().add(
                                AuthRegisterRequested(
                                  _emailController.text,
                                  _passwordController.text,
                                  _nameController.text,
                                ),
                              );
                        }
                      },
                      isLoading: state is AuthLoading,
                      isEnabled: _agreeToTerms,
                    ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Đã có tài khoản? ',
                      style: TextStyle(color: AppColors.gray600),
                    ),
                    AppTextButton(
                      label: 'Đăng nhập',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
}