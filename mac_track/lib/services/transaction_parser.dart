class TransactionDetails {
  final double amount;
  final String type; // 'credit', 'debit', 'upi', etc.
  final String? bank;
  final DateTime timestamp;

  TransactionDetails({
    required this.amount,
    required this.type,
    this.bank,
    required this.timestamp,
  });
}

class TransactionParser {
  static final List<RegExp> _regexList = [
    // Add more as needed
    RegExp(r'(?:debited|withdrawn).*?INR\s?([\d,]+\.\d{2})', caseSensitive: false),
    RegExp(r'INR\s?([\d,]+\.\d{2}).*?(?:credited|deposited)', caseSensitive: false),
    RegExp(r'paid to .*?UPI.*?INR\s?([\d,]+\.\d{2})', caseSensitive: false),
  ];

  static TransactionDetails? parse(String body, DateTime timestamp) {
    for (var regex in _regexList) {
      final match = regex.firstMatch(body);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        final amount = double.tryParse(amountStr ?? '');
        if (amount != null) {
          final type = body.toLowerCase().contains('credited') ||
                  body.toLowerCase().contains('deposited')
              ? 'credit'
              : body.toLowerCase().contains('debited') ||
                      body.toLowerCase().contains('withdrawn')
                  ? 'debit'
                  : 'upi';

          return TransactionDetails(
            amount: amount,
            type: type,
            timestamp: timestamp,
          );
        }
      }
    }
    return null;
  }
}
