import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../bloc/index.dart';
import '../../services/index.dart';
import '../../utils/index.dart';
import '../../widgets/index.dart';

// ── Dark theme colors ──
class _K {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const primary = Color(0xFF6366F1);
  static const emerald = Color(0xFF10B981);
  static const rose = Color(0xFFF43F5E);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const divider = Color(0xFF334155);
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onOrdersTap;
  const ProfileScreen({Key? key, this.onOrdersTap}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isValidSession = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final valid = await AuthService().verifyAuth();
    if (mounted) setState(() => _isValidSession = valid);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _K.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Đăng xuất', style: GoogleFonts.outfit(color: _K.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Bạn có chắc chắn muốn đăng xuất?', style: GoogleFonts.outfit(color: _K.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: GoogleFonts.outfit(color: _K.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _K.rose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Đăng xuất', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    if (!_isValidSession || !authService.isTokenValid || authService.currentUser == null) {
      return _buildUnauthenticatedUI();
    }

    final user = authService.currentUser!;

    return Scaffold(
      backgroundColor: _K.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // ── Profile Header Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _K.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _K.divider.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_K.primary, _K.emerald],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: _K.surface,
                        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                        child: user.avatarUrl == null
                            ? Text(
                                _getInitials(user.fullName),
                                style: GoogleFonts.outfit(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: _K.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.fullName,
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: _K.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: GoogleFonts.outfit(fontSize: 14, color: _K.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: _K.emerald.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: _K.emerald),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Settings ──
              Container(
                decoration: BoxDecoration(
                  color: _K.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _K.divider.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(Icons.person_outline_rounded, 'Chỉnh sửa hồ sơ', () {
                      Navigator.pushNamed(context, '/edit-profile');
                    }),
                    Divider(height: 1, color: _K.divider.withOpacity(0.3), indent: 56, endIndent: 16),
                    _buildSettingsTile(Icons.lock_outline_rounded, 'Đổi mật khẩu', () {
                      Navigator.pushNamed(context, '/change-password');
                    }),
                    Divider(height: 1, color: _K.divider.withOpacity(0.3), indent: 56, endIndent: 16),
                    _buildSettingsTile(Icons.shopping_bag_outlined, 'Đơn hàng của tôi', () {
                      if (widget.onOrdersTap != null) {
                        widget.onOrdersTap!();
                      } else {
                        Navigator.pushNamed(context, '/orders');
                      }
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Logout ──
              Container(
                decoration: BoxDecoration(
                  color: _K.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _K.divider.withOpacity(0.5)),
                ),
                child: _buildSettingsTile(Icons.logout_rounded, 'Đăng xuất', () => _showLogoutDialog(context),
                    iconColor: _K.rose, titleColor: _K.rose, showArrow: false),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap,
      {Color? iconColor, Color? titleColor, bool showArrow = true}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? _K.primary).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? _K.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor ?? _K.textPrimary),
      ),
      trailing: showArrow ? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _K.textMuted) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
    );
  }

  // ── UNAUTHENTICATED UI ──
  Widget _buildUnauthenticatedUI() {
    return Scaffold(
      backgroundColor: _K.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: _K.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: _K.primary.withOpacity(0.2), width: 2),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: _K.primary, size: 48),
                ),
                const SizedBox(height: 28),
                Text(
                  'Chào bạn!',
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: _K.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đăng nhập để quản lý tài khoản,\ntheo dõi đơn hàng và nhiều hơn nữa.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 14, color: _K.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),
                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/login'),
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: Text('Đăng nhập', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _K.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Register Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/register'),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: Text('Tạo tài khoản mới', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _K.primary,
                      side: BorderSide(color: _K.primary.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
