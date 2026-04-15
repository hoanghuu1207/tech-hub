import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/index.dart';
import '../../utils/index.dart';
import '../../widgets/index.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                // Logo & Title
                const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.devices_outlined,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: AppSpacing.lg),
                      Text(
                        'TechHub',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Mua sắm thiết bị công nghệ thông minh',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                // Email
                AppTextField(
                  label: 'Email',
                  hint: 'nhập email của bạn',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.validateEmail,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Password
                AppTextField(
                  label: 'Mật khẩu',
                  hint: 'nhập mật khẩu',
                  controller: _passwordController,
                  validator: AppValidators.validatePassword,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outlined),
                ),
                const SizedBox(height: AppSpacing.md),
                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: AppTextButton(
                    label: 'Quên mật khẩu?',
                    onPressed: () {
                      // TODO: Navigate to forgot password screen
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Login button
                BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is AuthSuccess) {
                      // Navigate to home
                      Navigator.of(context).pushReplacementNamed('/home');
                    } else if (state is AuthFailure) {
                      AppSnackbars.showError(context, state.message);
                    }
                  },
                  builder: (context, state) {
                    return AppButton(
                      label: 'Đăng Nhập',
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<AuthBloc>().add(
                                AuthLoginRequested(
                                  _emailController.text,
                                  _passwordController.text,
                                ),
                              );
                        }
                      },
                      isLoading: state is AuthLoading,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                // Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Chưa có tài khoản? ',
                      style: TextStyle(color: AppColors.gray600),
                    ),
                    AppTextButton(
                      label: 'Đăng ký ngay',
                      onPressed: () {
                        Navigator.of(context).pushNamed('/register');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Demo button for testing
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Khám phá ứng dụng (Demo)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppColors.secondary),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Center(
                  child: Text(
                    'Không có tài khoản? Dùng chế độ Demo để khám phá ứng dụng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.gray500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
