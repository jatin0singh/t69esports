import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connectivity_service.dart';
import 'offline_meme_card.dart';

class NoInternetScreen extends ConsumerStatefulWidget {
  final VoidCallback? onDismiss;
  final bool showDismissButton;

  const NoInternetScreen({
    super.key,
    this.onDismiss,
    this.showDismissButton = true,
  });

  @override
  ConsumerState<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends ConsumerState<NoInternetScreen> {
  bool _isChecking = false;
  String? _statusMessage;

  Future<void> _handleRetry() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _statusMessage = 'Pinging servers & testing network connection...';
    });

    final isOnline =
        await ref.read(connectivityStateProvider.notifier).checkNow();

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      if (isOnline) {
        _statusMessage = '✅ Connection restored! Redirecting...';
      } else {
        _statusMessage = '❌ Still offline. Please check your Wi-Fi or Mobile Data.';
      }
    });

    if (isOnline && widget.onDismiss != null) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        widget.onDismiss?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Column(
          children: [
            // Top Status Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'CONNECTION LOST • OFFLINE MODE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFEF4444),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  if (widget.showDismissButton && widget.onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: widget.onDismiss,
                      tooltip: 'Close offline screen',
                    ),
                ],
              ),
            ),

            // Main Scrollable Area with the Meme Card
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // The Johnny Sins / Mia Khalifa "Dogs of Amazon" Style Card
                    const OfflineMemeCard(),

                    // Feedback status banner if retry was pressed
                    if (_statusMessage != null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _statusMessage!.startsWith('✅')
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _statusMessage!.startsWith('✅')
                                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                : const Color(0xFFEF4444).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _statusMessage!.startsWith('✅')
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Primary Action: Retry Connection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isChecking ? null : _handleRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A3E0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF00A3E0).withValues(alpha: 0.4),
                          ),
                          child: _isChecking
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'TESTING SIGNAL...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.refresh_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'RETRY CONNECTION',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    if (widget.showDismissButton && widget.onDismiss != null) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: widget.onDismiss,
                        child: Text(
                          'Browse Cached Matches in Offline Mode',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
