import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorDialog extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    required this.message,
    this.title,
    this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title ?? 'Error',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.red[700],
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: Text(
            'OK',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4C57D6),
            ),
          ),
        ),
      ],
    );
  }
}

class SuccessDialog extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onDismiss;

  const SuccessDialog({
    required this.message,
    this.title,
    this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title ?? 'Success',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.green[700],
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: Text(
            'OK',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4C57D6),
            ),
          ),
        ),
      ],
    );
  }
}

class ValidationErrorDialog extends StatelessWidget {
  final Map<String, List<String>> errors;
  final VoidCallback? onDismiss;

  const ValidationErrorDialog({
    required this.errors,
    this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final errorList = errors.entries.toList();

    return AlertDialog(
      title: Text(
        'Validation Errors',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.red[700],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children:
              errorList.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...entry.value.map((error) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              Expanded(
                                child: Text(
                                  error,
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: Text(
            'OK',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4C57D6),
            ),
          ),
        ),
      ],
    );
  }
}
