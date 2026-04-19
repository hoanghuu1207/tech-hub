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

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
       parent: _animationController,
       curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Graphic header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: const SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'app_logo',
                        child: Icon(
                          Icons.bolt_rounded,
                          size: 72,
                          color: AppColors.white,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'TechHub',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Premium Tech Store',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.gray300,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Slide-up Form Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.65,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxxl),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Đăng nhập',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Chào mừng bạn quay trở lại TechHub',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.gray500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        
                        AppTextField(
                          label: 'Email',
                          hint: 'Nhập email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: AppValidators.validateEmail,
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.gray500),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'Mật khẩu',
                          hint: 'Nhập mật khẩu',
                          controller: _passwordController,
                          validator: AppValidators.validatePassword,
                          obscureText: true,
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.gray500),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Quên mật khẩu?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        
                        BlocConsumer<AuthBloc, AuthState>(
                          listener: (context, state) {
                            if (state is AuthSuccess) {
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
                        const SizedBox(height: AppSpacing.xl),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Chưa có tài khoản? ',
                              style: TextStyle(color: AppColors.gray600),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushNamed('/register');
                              },
                              child: const Text(
                                'Đăng ký ngay',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.electricBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
                            icon: const Icon(Icons.explore_outlined),
                            label: const Text('Tiếp tục như Khách'),
                            style: TextButton.styleFrom(
                               foregroundColor: AppColors.gray600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
