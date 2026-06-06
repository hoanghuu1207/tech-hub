import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/cart_bloc.dart';
import '../services/order_service.dart';
import 'payment_result_screen.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String orderId;

  const PaymentWebViewScreen({
    Key? key,
    required this.checkoutUrl,
    required this.orderId,
  }) : super(key: key);

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  bool _isLoading = true;
  bool _navigated = false;

  void _goToResult({required bool isSuccess, String? orderId}) {
    if (_navigated || !mounted) return;
    _navigated = true;
    final resolvedOrderId = orderId ?? widget.orderId;

    if (isSuccess) {
      context.read<CartBloc>().add(const CartFetch());
    } else {
      // Gọi API hủy đơn để cập nhật payment_status = failed trong DB
      OrderService().cancelOrder(resolvedOrderId);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(
          isSuccess: isSuccess,
          orderId: resolvedOrderId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: _onClose,
        ),
        title: Text('Thanh toán PayOS',
          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.checkoutUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
            ),
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url.toString();

              // 1. Intercept techhub:// deep link
              if (url.startsWith('techhub://')) {
                _handleResultUrl(url);
                return NavigationActionPolicy.CANCEL;
              }

              // 2. For cancelled payments: ALLOW the redirect page to load
              //    so the backend can update payment_status in the DB.
              //    For success: intercept immediately (webhook handles DB).
              if (url.contains('/api/v1/payment/result')) {
                final uri = Uri.parse(url);
                final status = uri.queryParameters['status'] ?? '';
                if (status == 'success') {
                  // Webhook đã cập nhật DB, navigate ngay
                  _handleResultUrl(url);
                  return NavigationActionPolicy.CANCEL;
                }
                // cancelled → cho page load để backend cập nhật DB
                return NavigationActionPolicy.ALLOW;
              }

              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (_, __) {
              if (mounted) setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) {
              if (mounted) setState(() => _isLoading = false);
              // Fallback: if the result page somehow loaded
              final currentUrl = url?.toString() ?? '';
              if (currentUrl.contains('/api/v1/payment/result')) {
                _handleResultUrl(currentUrl);
              }
            },
            onReceivedError: (controller, request, error) {
              final url = request.url.toString();
              // techhub:// scheme error → parse and navigate
              if (url.startsWith('techhub://')) {
                _handleResultUrl(url);
                return;
              }
              if (mounted && _isLoading) {
                setState(() => _isLoading = false);
              }
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 3),
            ),
        ],
      ),
    );
  }

  /// Parse status & orderId from any result URL and navigate
  void _handleResultUrl(String url) {
    final uri = Uri.parse(url);
    final statuses = uri.queryParametersAll['status'] ?? [];
    final isSuccess = statuses.any((s) {
      final lower = s.toLowerCase();
      return lower == 'success' || lower == 'paid';
    });
    final orderId = uri.queryParameters['orderId'] ?? widget.orderId;
    _goToResult(isSuccess: isSuccess, orderId: orderId);
  }

  void _onClose() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hủy thanh toán?',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Bạn có chắc muốn hủy thanh toán? Đơn hàng sẽ bị hủy.',
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tiếp tục', style: GoogleFonts.outfit(color: const Color(0xFF6366F1))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToResult(isSuccess: false);
            },
            child: Text('Hủy', style: GoogleFonts.outfit(color: const Color(0xFFF43F5E))),
          ),
        ],
      ),
    );
  }
}
