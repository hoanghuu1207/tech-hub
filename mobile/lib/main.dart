import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'bloc/index.dart';
import 'screens/index.dart';
import 'services/index.dart';
import 'utils/index.dart';
import 'widgets/app_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    try {
      await dotenv.load(fileName: '.env');
      print('✅ .env loaded successfully');
    } catch (e) {
      print('⚠️ Warning loading .env: $e');
      // Continue - .env không bắt buộc trong dev
    }

    // Initialize AuthService singleton
    await AuthService().init();
    print('✅ AuthService initialized');
  } catch (e) {
    print('❌ Error initializing AuthService: $e');
    // Tiếp tục vì AuthService có fallback values
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (context) => AuthBloc()),
        BlocProvider<ProductBloc>(create: (context) => ProductBloc()),
        BlocProvider<CartBloc>(create: (context) => CartBloc()),
        BlocProvider<ChatBloc>(create: (context) => ChatBloc()),
      ],
      child: MaterialApp(
        title: 'TechHub',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const SplashScreen(),
        routes: _buildRoutes(),
        onGenerateRoute: (settings) {
          if (settings.name == '/product-detail') {
            final productId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) =>
                  PlaceholderScreen(title: 'Product: $productId'),
            );
          }
          return null;
        },
      ),
    );
  }

  static ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
        iconTheme: IconThemeData(color: AppColors.black),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AppColors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.gray600,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
    );
  }

  static Map<String, WidgetBuilder> _buildRoutes() {
    return {
      '/login': (context) => const LoginScreen(),
      '/register': (context) => const RegisterScreen(),
      '/home': (context) => const HomeScreen(),
      '/chat': (context) => const ChatScreen(),
      '/cart': (context) => const CartScreen(),
      '/search': (context) => const PlaceholderScreen(title: 'Search'),
      '/products': (context) => const PlaceholderScreen(title: 'Products'),
      '/products-by-category': (context) =>
          const PlaceholderScreen(title: 'Category'),
      '/product-detail': (context) =>
          const PlaceholderScreen(title: 'Product Detail'),
      '/checkout': (context) => const PlaceholderScreen(title: 'Checkout'),
      '/orders': (context) => const PlaceholderScreen(title: 'Orders'),
      '/profile': (context) => const PlaceholderScreen(title: 'Profile'),
    };
  }
}

// Splash screen - FIX: Better error handling
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      final authService = AuthService();
      if (authService.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi khởi tạo: $e';
        });
        print('❌ Splash error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Lỗi Khởi Tạo',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.gray600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Thử lại',
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _checkAuth();
                },
                width: 150,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.devices_outlined,
              size: 80,
              color: AppColors.white,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'TechHub',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Mua sắm thiết bị công nghệ thông minh',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder for screens in development
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 80, color: AppColors.gray300),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '$title - Đang phát triển',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
