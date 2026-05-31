import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Payment Result Screen — matches Stitch "Payment Successful" / "Payment Failed" designs.
class PaymentResultScreen extends StatefulWidget {
  final bool isSuccess;
  final String orderId;

  const PaymentResultScreen({
    Key? key,
    required this.isSuccess,
    required this.orderId,
  }) : super(key: key);

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _fadeController;
  late Animation<double> _iconScale;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _iconScale = CurvedAnimation(parent: _iconController, curve: Curves.elasticOut);
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _iconController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Animated Icon ──
                        ScaleTransition(
                          scale: _iconScale,
                          child: _buildIconCircle(),
                        ),
                        const SizedBox(height: 36),
                        // ── Title ──
                        FadeTransition(
                          opacity: _fadeIn,
                          child: Text(
                            widget.isSuccess
                                ? 'Thanh toán thành công!'
                                : 'Thanh toán thất bại',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ── Subtitle ──
                        FadeTransition(
                          opacity: _fadeIn,
                          child: Text(
                            widget.isSuccess
                                ? 'Đơn hàng đã được xác nhận thành công.'
                                : 'Đã xảy ra lỗi trong quá trình thanh toán.',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: const Color(0xFF94A3B8),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Info text ──
                        FadeTransition(
                          opacity: _fadeIn,
                          child: Text(
                            widget.isSuccess
                                ? 'Biên lai đã được gửi đến email của bạn'
                                : 'Vui lòng kiểm tra thông tin thanh toán và thử lại.',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Bottom Section ──
              FadeTransition(
                opacity: _fadeIn,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Order ID
                      if (widget.orderId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            'Mã đơn hàng: #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase()}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      // Primary action — Return to home
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _goHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Về trang chủ',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      // Try again — only for failed
                      if (!widget.isSuccess) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Thử lại',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconCircle() {
    final color =
        widget.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: widget.isSuccess
            ? _AnimatedCheck(color: color)
            : _AnimatedCross(color: color),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }
}

/// Animated checkmark drawn with a custom painter
class _AnimatedCheck extends StatefulWidget {
  final Color color;
  const _AnimatedCheck({required this.color});

  @override
  State<_AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<_AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        size: const Size(48, 48),
        painter: _CheckPainter(
          progress: _controller.value,
          color: widget.color,
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Checkmark points
    final p1 = Offset(size.width * 0.2, size.height * 0.5);
    final p2 = Offset(size.width * 0.4, size.height * 0.7);
    final p3 = Offset(size.width * 0.8, size.height * 0.3);

    path.moveTo(p1.dx, p1.dy);

    if (progress <= 0.5) {
      // First segment
      final t = progress / 0.5;
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      // Full first + partial second
      path.lineTo(p2.dx, p2.dy);
      final t = (progress - 0.5) / 0.5;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress;
}

/// Animated X mark
class _AnimatedCross extends StatefulWidget {
  final Color color;
  const _AnimatedCross({required this.color});

  @override
  State<_AnimatedCross> createState() => _AnimatedCrossState();
}

class _AnimatedCrossState extends State<_AnimatedCross>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        size: const Size(40, 40),
        painter: _CrossPainter(
          progress: _controller.value,
          color: widget.color,
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CrossPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final inset = size.width * 0.15;

    if (progress <= 0.5) {
      // First line of X
      final t = progress / 0.5;
      canvas.drawLine(
        Offset(inset, inset),
        Offset(
          inset + (size.width - 2 * inset) * t,
          inset + (size.height - 2 * inset) * t,
        ),
        paint,
      );
    } else {
      // Full first + partial second
      canvas.drawLine(
        Offset(inset, inset),
        Offset(size.width - inset, size.height - inset),
        paint,
      );
      final t = (progress - 0.5) / 0.5;
      canvas.drawLine(
        Offset(size.width - inset, inset),
        Offset(
          (size.width - inset) - (size.width - 2 * inset) * t,
          inset + (size.height - 2 * inset) * t,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.progress != progress;
}
