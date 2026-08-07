import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../app_state.dart';
import '../flutter_flow/nav/nav.dart';

/// Centralized toast/snackbar service for the entire application.
///
/// Usage:
///   ToastService.success(context, 'Customer created successfully!');
///   ToastService.error(context, 'Something went wrong');
///   ToastService.warning(context, 'Please fill all required fields');
///   ToastService.info(context, 'Job updated');
///   ToastService.show(context, 'Custom message', type: ToastType.success);
///
/// Message can be a String, List<String>, or Map (extracts 'message' key):
///   ToastService.error(context, ['Email is required', 'Name is required']);
///   ToastService.error(context, {'message': 'Server error'});
///
/// This service uses the [globalMessengerKey] which is registered at the root
/// MaterialApp level so that every toast is rendered at the very top of the
/// widget tree — above modals, bottom sheets, dialogs, and navigation bars.

enum ToastType { success, error, warning, info }

class ToastService {
  // ─── Private colour constants ─────────────────────────────────────────────
  static const Color _successColor = Color(0xFF10B981); // emerald-500
  static const Color _errorColor   = Color(0xFFEF4444); // red-500
  static const Color _warningColor = Color(0xFFF59E0B); // amber-500
  static const Color _infoColor    = Color(0xFF3B82F6); // blue-500

  // ─── Private icon constants ───────────────────────────────────────────────
  static const IconData _successIcon = Icons.check_circle_outline_rounded;
  static const IconData _errorIcon   = Icons.error_outline_rounded;
  static const IconData _warningIcon = Icons.warning_amber_rounded;
  static const IconData _infoIcon    = Icons.info_outline_rounded;

  // ─── Public API ───────────────────────────────────────────────────────────

  static void success(BuildContext context, dynamic message, {int duration = 4}) =>
      show(context, message, type: ToastType.success, duration: duration);

  static void error(BuildContext context, dynamic message, {int duration = 5}) =>
      show(context, message, type: ToastType.error, duration: duration);

  static void warning(BuildContext context, dynamic message, {int duration = 4}) =>
      show(context, message, type: ToastType.warning, duration: duration);

  static void info(BuildContext context, dynamic message, {int duration = 4}) =>
      show(context, message, type: ToastType.info, duration: duration);

  /// For callers that already have a [ScaffoldMessengerState] (e.g. services
  /// without a BuildContext). Prefer [show] in normal widgets.
  static void showWithMessenger(
    ScaffoldMessengerState messenger,
    dynamic message, {
    ToastType type = ToastType.info,
    int duration = 4,
    VoidCallback? onTap,
  }) {
    final text  = _extractMessage(message);
    final color = _colorForType(type);
    final icon  = _iconForType(type);
    _showRaw(messenger, text, color, icon, duration, onTap);
  }

  /// Core show method.
  /// [message] can be a String, List, or Map (with a 'message' key).
  static void show(
    BuildContext context,
    dynamic message, {
    ToastType type = ToastType.info,
    int duration = 4,
    VoidCallback? onTap,
  }) {
    final text = _extractMessage(message);
    final color = _colorForType(type);
    final icon  = _iconForType(type);

    // Use the global messenger key so the toast is rendered in the root overlay
    // (above all Navigator routes, modals, dialogs, and bottom sheets).
    final messengerState = globalMessengerKey.currentState;
    if (messengerState == null) {
      // Fallback: use context directly if global key is not yet attached.
      try {
        _showRaw(ScaffoldMessenger.of(context), text, color, icon, duration, onTap);
      } catch (_) {}
      return;
    }

    _showRaw(messengerState, text, color, icon, duration, onTap);
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  static String _extractMessage(dynamic message) {
    if (message is String) {
      return message.replaceAll('Exception: ', '').trim();
    }
    if (message is List) {
      return message
          .map((e) => e.toString().replaceAll('Exception: ', '').trim())
          .where((s) => s.isNotEmpty)
          .join('\n');
    }
    if (message is Map) {
      final v = message['message'] ?? message['error'] ?? message['msg'] ?? message.values.firstOrNull;
      return _extractMessage(v ?? message.toString());
    }
    return message?.toString().replaceAll('Exception: ', '').trim() ?? 'Something went wrong';
  }

  static Color _colorForType(ToastType type) {
    switch (type) {
      case ToastType.success: return _successColor;
      case ToastType.error:   return _errorColor;
      case ToastType.warning: return _warningColor;
      case ToastType.info:    return _infoColor;
    }
  }

  static IconData _iconForType(ToastType type) {
    switch (type) {
      case ToastType.success: return _successIcon;
      case ToastType.error:   return _errorIcon;
      case ToastType.warning: return _warningIcon;
      case ToastType.info:    return _infoIcon;
    }
  }

  static OverlayEntry? _currentOverlay;

  static void _showRaw(
    ScaffoldMessengerState messenger,
    String text,
    Color color,
    IconData icon,
    int duration,
    [VoidCallback? onTap]
  ) {
    final context = messenger.context;
    // Get the root overlay from the global key we created in main.dart
    final overlayState = globalOverlayKey.currentState;
    if (overlayState == null) return;
    
    _currentOverlay?.remove();
    _currentOverlay = null;

    late OverlayEntry overlayEntry;
    bool isRemoved = false;
    
    overlayEntry = OverlayEntry(
      builder: (context) {
        // padding.top handles the physical device notch/status bar (it is 0 on the web)
        // Accessing MediaQuery on inactive web tabs can cause engine assertions, so we bypass it.
        final double topPadding = kIsWeb ? 0 : MediaQuery.of(context).padding.top;
        return Positioned(
          top: topPadding + 15,
          left: 20,
          right: 20,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                if (onTap != null) onTap();
                if (!isRemoved && _currentOverlay == overlayEntry) {
                  isRemoved = true;
                  overlayEntry.remove();
                  _currentOverlay = null;
                }
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentOverlay = overlayEntry;
    
    // Use Future.microtask to defer the insertion safely outside of any active synchronous pipeline.
    // This avoids Flutter Web engine assertions while ensuring it runs before the next frame,
    // so the toast is guaranteed to show up.
    Future.microtask(() {
      overlayState.insert(overlayEntry);
      
      Future.delayed(Duration(seconds: duration), () {
        if (!isRemoved && _currentOverlay == overlayEntry) {
          isRemoved = true;
          overlayEntry.remove();
          _currentOverlay = null;
        }
      });
    });
  }
}
