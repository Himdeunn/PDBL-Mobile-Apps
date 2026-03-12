import 'package:flutter/material.dart';
import 'navigator_service.dart';

class ErrorHandler {
  static void showSuccessPopup(String message, {String? title}) {
    final context = NavigatorService.context;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text(title ?? 'Success', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showErrorPopup(String message, {String? title}) {
    final context = NavigatorService.context;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Text(title ?? 'Error', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void handleApiError(dynamic error) {
    if (error.toString().contains('SocketException') || 
        error.toString().toLowerCase().contains('connection failed') ||
        error.toString().toLowerCase().contains('failed host lookup')) {
      showErrorPopup('No internet connection or server is offline.', title: 'Server Offline');
    } else if (error.toString().contains('401')) {
      showErrorPopup('Your session has expired. Please log in again.', title: 'Session Expired');
    } else if (error.toString().contains('403')) {
      showErrorPopup('You do not have permission to perform this action.', title: 'Access Denied');
    } else {
      // Clean up the error message if it's too long
      String msg = error.toString();
      if (msg.length > 100) {
        msg = msg.substring(0, 97) + '...';
      }
      showErrorPopup(msg, title: 'Error');
    }
  }
}
