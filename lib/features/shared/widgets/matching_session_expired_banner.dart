import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchingSessionExpiredBanner extends StatelessWidget {
  final int secondsRemaining;
  final VoidCallback? onRetry;

  const MatchingSessionExpiredBanner({
    super.key,
    required this.secondsRemaining,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isExpired = secondsRemaining <= 0;
    final isWarning = secondsRemaining <= 30 && secondsRemaining > 0;

    if (!isExpired && !isWarning) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isExpired
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
        border: Border(
          left: BorderSide(
            color: isExpired ? Colors.red : Colors.orange,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.error_outline : Icons.warning_amber,
            color: isExpired ? Colors.red : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired
                      ? 'Matching session expired'
                      : 'Matching session expiring soon',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isExpired
                      ? 'Please search for drivers again'
                      : 'Time remaining: ${secondsRemaining}s',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        isDarkMode ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          if (isExpired && onRetry != null)
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('Retry', style: GoogleFonts.poppins(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
