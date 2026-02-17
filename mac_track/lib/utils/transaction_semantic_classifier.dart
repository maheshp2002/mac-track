import 'dart:convert';
import 'package:flutter/services.dart';
import '../config/constants.dart';

class CsvSemanticResult {
  final String inferredCategoryName;
  final String inferredExpenseName;
  final double confidence;

  CsvSemanticResult({
    required this.inferredCategoryName,
    required this.inferredExpenseName,
    required this.confidence,
  });
}

class TransactionSemanticClassifier {
  static Map<String, List<String>> _dictionary = {};

  /// Load JSON dictionary from assets (only once).
  static Future<void> loadDictionary() async {
    final jsonStr = await rootBundle
        .loadString('assets/transaction_dictionary.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;

    _dictionary.clear();
    data.forEach((category, list) {
      _dictionary[category] =
          (list as List).map((e) => e.toString()).toList();
    });
  }

  static CsvSemanticResult infer(String rawDesc) {
    final desc = _normalize(rawDesc);

    String bestCategory = AppConstants.otherCategory;
    String bestKeyword = '';
    double bestScore = 0;

    _dictionary.forEach((category, keywords) {
      for (final keyword in keywords) {
        final normKey = _normalize(keyword);
        if (desc.contains(normKey)) {
          final specificity = _specificityBonus(normKey);
          final confidence = normKey.length * specificity;

          if (confidence > bestScore) {
            bestScore = confidence;
            bestCategory = category;
            bestKeyword = normKey;
          }
        }
      }
    });

    if (bestScore > 0) {
      return CsvSemanticResult(
        inferredCategoryName: bestCategory,
        inferredExpenseName: bestKeyword,
        confidence: bestScore,
      );
    }

    return CsvSemanticResult(
      inferredCategoryName: AppConstants.otherCategory,
      inferredExpenseName: _fallbackLabel(rawDesc),
      confidence: 0.1,
    );
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double _specificityBonus(String keyword) {
    if (keyword.length > 10) return 1.2;
    if (keyword.length > 6) return 1.1;
    return 1.0;
  }

  static String _fallbackLabel(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    return parts.take(2).join(' ');
  }
}
