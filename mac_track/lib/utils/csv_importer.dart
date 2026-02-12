import '../config/constants.dart';

class CsvSemanticResult {
  final String inferredCategoryName;
  final String inferredExpenseName;

  CsvSemanticResult({
    required this.inferredCategoryName,
    required this.inferredExpenseName,
  });
}

class CsvSemanticDictionary {
  static final Map<String, String> _keywordToCategory = {
    'swiggy': 'Food',
    'zomato': 'Food',
    'uber': 'Travel',
    'ola': 'Travel',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'netflix': 'Entertainment',
    'electricity': 'Utilities',
    'recharge': 'Utilities',
    'fuel': 'Fuel',
    'petrol': 'Fuel',
  };

  static CsvSemanticResult infer(String rawDescription) {
    final desc = rawDescription.toLowerCase().trim();

    for (final entry in _keywordToCategory.entries) {
      if (desc.contains(entry.key)) {
        return CsvSemanticResult(
          inferredCategoryName: entry.value,
          inferredExpenseName: entry.key,
        );
      }
    }

    // Fall back to Other with a simple label
    return CsvSemanticResult(
      inferredCategoryName: AppConstants.otherCategory,
      inferredExpenseName:
          rawDescription.split(' ').take(2).join(' '),
    );
  }
}
