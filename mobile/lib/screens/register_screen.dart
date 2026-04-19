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
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Tạo Tài Khoản',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Trải nghiệm mua sắm công nghệ đỉnh cao',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                
                // Form Fields
                AppTextField(
                  label: 'Họ và tên',
                  hint: 'Nhập họ và tên',
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  validator: AppValidators.validateFullName,
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.gray500),
                ),
                const SizedBox(height: AppSpacing.lg),
                
                AppTextField(
                  label: 'Email',
                  hint: 'Nhập email của bạn',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.validateEmail,
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.gray500),
                ),
                const SizedBox(height: AppSpacing.lg),
                
                AppTextField(
                  label: 'Số điện thoại (Tuỳ chọn)',
                  hint: 'Nhập số điện thoại',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.gray500),
                ),
                const SizedBox(height: AppSpacing.lg),
                
                AppTextField(
                  label: 'Mật khẩu',
                  hint: 'Tối thiểu 6 ký tự',
                  controller: _passwordController,
                  validator: AppValidators.validatePassword,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.gray500),
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
                  prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.gray500),
                ),
                const SizedBox(height: AppSpacing.lg),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _agreeToTerms,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (value) {
                          setState(() {
                            _agreeToTerms = value ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _agreeToTerms = !_agreeToTerms;
                          });
                        },
                        child: const Text(
                          'Tôi đồng ý với Điều khoản dịch vụ và Chính sách bảo mật của TechHub',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.gray600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxxl),
                
                BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is AuthSuccess) {
                      AppSnackbars.showSuccess(context, 'Đăng ký thành công!');
                      Navigator.of(context).pushReplacementNamed('/home');
                    } else if (state is AuthFailure) {
                      AppSnackbars.showError(context, state.message);
                    }
                  },
                  builder: (context, state) {
                    return AppButton(
                      label: 'Đăng Ký',
                      onPressed: () {
                        if (!_agreeToTerms) {
                          AppSnackbars.showError(context, 'Bạn cần đồng ý với Điều khoản dịch vụ');
                          return;
                        }
                        if (_formKey.currentState!.validate()) {
                          context.read<AuthBloc>().add(
                                AuthRegisterRequested(
                                  email: _emailController.text,
                                  password: _passwordController.text,
                                  fullName: _nameController.text,
                                  phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
                                ),
                              );
                        }
                      },
                      isLoading: state is AuthLoading,
                      isEnabled: true, // we handle unchecked box inside onPressed
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Đã có tài khoản? ',
                      style: TextStyle(color: AppColors.gray600),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.electricBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}