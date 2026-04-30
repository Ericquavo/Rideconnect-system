/// Currency Formatter Service
/// Formats prices in RWF (Rwandan Francs)
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats a price in RWF
  /// Examples:
  /// - formatPrice(3500) => "3,500 RWF"
  /// - formatPrice(1200.50) => "1,200 RWF"
  static String formatPrice(dynamic price) {
    try {
      final amount =
          price is String
              ? double.tryParse(price) ?? 0
              : (price as num).toDouble();

      // Convert from USD-like values to RWF (approximate: 1 USD ≈ 1000 RWF)
      // For now, we'll show the value directly as RWF
      final rwf = amount.round();

      // Format with comma separator
      final parts = rwf.toString().split('.');
      final intPart = parts[0];
      final formatted = _addCommas(intPart);

      return '$formatted RWF';
    } catch (_) {
      return '0 RWF';
    }
  }

  /// Adds thousand separators to a number string
  static String _addCommas(String number) {
    if (number.length <= 3) return number;

    final reversed = number.split('').reversed.join();
    final chunks = <String>[];

    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3).clamp(0, reversed.length);
      chunks.add(reversed.substring(i, end));
    }

    return chunks.join(',').split('').reversed.join();
  }

  /// Formats price for ride type estimates (e.g., "From 3,500 RWF")
  static String formatEstimate(dynamic price) {
    return 'From ${formatPrice(price)}';
  }
}
