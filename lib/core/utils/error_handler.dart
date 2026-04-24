import 'package:flutter/material.dart';
import 'navigator_service.dart';
import 'dart:async';

class ErrorHandler {
  static bool _isSessionExpiredShowing = false;

  static void showSuccessPopup(String message, {String? title}) {
    _showTopNotification(
      message,
      title: title ?? 'Success',
      backgroundColor: Colors.green.shade600,
      icon: Icons.check_circle,
    );
  }

  static void _showTopNotification(
    String message, {
    required String title,
    required Color backgroundColor,
    required IconData icon,
  }) {
    // Attempt to get the current context or fallback to navigator context
    final overlay = NavigatorService.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }

    // Deduplicate "Session Expired" popups
    if (title.toLowerCase().contains('expired') || 
        message.toLowerCase().contains('expired') || 
        title.toLowerCase().contains('unauthorized')) {
      if (_isSessionExpiredShowing) return;
      _isSessionExpiredShowing = true;
      Timer(const Duration(seconds: 3), () {
        _isSessionExpiredShowing = false;
      });
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _SlidingNotification(
        title: title,
        message: message,
        backgroundColor: backgroundColor,
        icon: icon,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
    
    // Auto dismiss after 5.5 seconds to allow exit animation to finish
    Timer(const Duration(milliseconds: 5500), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  static void showErrorPopup(String message, {String? title}) {
    _showTopNotification(
      message,
      title: title ?? 'Error',
      backgroundColor: Colors.red.shade600,
      icon: Icons.error_outline,
    );
  }

  static void handleApiError(dynamic error) {
    String title = 'Error';
    String message = '';

    try {
      final errorStr = error.toString();
      if (errorStr.contains('DioException')) {
        final response = (error as dynamic).response;
        if (response != null && response.data is Map) {
          message = response.data['message']?.toString() ?? '';
          // Extract first validation error from Laravel's nested errors format
          if (message == 'The given data was invalid.' || message.isEmpty) {
            final errors = response.data['errors'];
            if (errors is Map && errors.isNotEmpty) {
              final firstErrors = errors.values.first;
              if (firstErrors is List && firstErrors.isNotEmpty) {
                message = firstErrors.first.toString();
              }
            }
          }
        }
        // Non-JSON responses (HTML proxy pages, etc.) are intentionally ignored here
        // and fall through to the generic fallback below
      }

      // Fallback: try the .message property on the error object
      if (message.isEmpty) {
        final msg = (error as dynamic).message;
        if (msg is String && msg.isNotEmpty) {
          message = msg;
        }
      }
    } catch (_) {
      // Ignore — fallback to generic message below
    }

    // Remove "Exception: " prefix from generic Dart exceptions
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    // Replace any technical/sensitive content with a safe user-facing message
    final isTechnical = message.isEmpty ||
        message == 'null' ||
        message.contains('http://') ||
        message.contains('https://') ||
        message.contains('HandshakeException') ||
        message.contains('SocketException') ||
        message.contains('uri:') ||
        message.contains('<!') ||
        message.contains('ERR_') ||
        RegExp(r'^[A-Z_]+$').hasMatch(message);

    if (isTechnical) {
      message = 'Something went wrong. Please try again.';
    }

    final msgLower = message.toLowerCase();
    if (msgLower.contains('socket') ||
        msgLower.contains('connection') ||
        msgLower.contains('network') ||
        msgLower.contains('host lookup') ||
        msgLower.contains('is not reachable')) {
      return;
    } else if (msgLower.contains('expired') || msgLower.contains('unauthorized')) {
      title = 'Session Expired';
      message = 'Your session has expired. Please log in again.';
    } else if (msgLower.contains('permission') || msgLower.contains('access denied')) {
      title = 'Access Denied';
      message = 'You do not have permission to perform this action.';
    } else if (msgLower.contains('too many') || msgLower.contains('rate limit')) {
      title = 'Too Many Attempts';
    } else if (msgLower.contains('internal error') || msgLower.contains('server error')) {
      return;
    }

    showErrorPopup(message, title: title);
  }
}

class _SlidingNotification extends StatefulWidget {
  final String title;
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback onDismiss;

  const _SlidingNotification({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_SlidingNotification> createState() => _SlidingNotificationState();
}

class _SlidingNotificationState extends State<_SlidingNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -2.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    // Start exit animation after 4.5 seconds
    Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        _controller.animateTo(-0.1, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
          .then((_) => _controller.animateTo(-2.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInCubic));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
