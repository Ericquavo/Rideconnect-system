import 'package:flutter/material.dart';

/// Display a success toast message using SnackBar
void showSuccessToast(String message) {
  _showSnackBar(message, Colors.green);
}

/// Display an error toast message using SnackBar
void showErrorToast(String message) {
  _showSnackBar(message, Colors.red);
}

/// Display an info toast message using SnackBar
void showInfoToast(String message) {
  _showSnackBar(message, Colors.blue);
}

/// Display a loading toast message using SnackBar
void showLoadingToast(String message) {
  _showSnackBar(message, Colors.grey[700] ?? Colors.grey);
}

/// Internal helper to show SnackBar
void _showSnackBar(String message, Color backgroundColor) {
  // Note: This requires a BuildContext to work properly
  // In the calling code, you should pass the context to ScaffoldMessenger directly
  // This is a simplified version that uses the last active ScaffoldMessenger
  try {
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    // If no context available, silently fail
    // In production, you'd want to log this
  }
}

// This global key should be provided by your main.dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
