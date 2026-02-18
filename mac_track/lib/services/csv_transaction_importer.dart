import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/utils/transaction_semantic_classifier.dart';
import 'transaction_field_dictionary.dart';

class CsvTransactionImporter {
  Future<List<Map<String, dynamic>>> importCsv({
    required String filePath,
    required String selectedBankId,
    required Map<String, String> expenseCategoryMap,
  }) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final rows = CsvCodec().decoder.convert(content);

    if (rows.isEmpty) {
      throw Exception("CSV is empty");
    }

    // ---------------------------
    // STEP 1: Detect Header Row
    // ---------------------------
    int? headerRowIndex;
    Map<String, int> fieldIndexMap = {};

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      final tempMap = <String, int>{};

      for (int c = 0; c < row.length; c++) {
        final cell = row[c].toString();
        final detected = TransactionFieldDictionary.detectField(cell);
        if (detected != null && !tempMap.containsKey(detected)) {
          tempMap[detected] = c;
        }
      }

      if (tempMap.containsKey("description") &&
          (tempMap.containsKey("debit") ||
              tempMap.containsKey("amount"))) {
        headerRowIndex = r;
        fieldIndexMap = tempMap;
        break;
      }
    }

    if (headerRowIndex == null) {
      throw Exception("Unable to detect header row.");
    }

    final hasDebitCredit =
        fieldIndexMap.containsKey("debit") &&
        fieldIndexMap.containsKey("credit");

    final hasAmountOnly = fieldIndexMap.containsKey("amount");
    final hasTypeColumn = fieldIndexMap.containsKey("type");
    final hasDate = fieldIndexMap.containsKey("date");

    if (!hasDebitCredit && !hasAmountOnly) {
      throw Exception(
          "Unsupported format: No debit/credit or amount column.");
    }

    final parsedExpenses = <Map<String, dynamic>>[];

    // ---------------------------
    // STEP 2: Parse Transactions
    // ---------------------------
    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      try {
        final descIdx = fieldIndexMap["description"]!;
        if (descIdx >= row.length) continue;

        final rawDescription =
            row[descIdx].toString().trim();
        if (rawDescription.isEmpty) continue;

        double amount = 0;
        String transactionType =
            AppConstants.transactionTypeWithdraw;

        String sanitize(String value) => value
            .replaceAll(',', '')
            .replaceAll('₹', '')
            .replaceAll('INR', '')
            .trim();

        // ---------------------------
        // Amount Parsing
        // ---------------------------
        if (hasDebitCredit) {
          final debitIdx = fieldIndexMap["debit"]!;
          final creditIdx = fieldIndexMap["credit"]!;

          final debitVal = debitIdx < row.length
              ? sanitize(row[debitIdx].toString())
              : "";

          final creditVal = creditIdx < row.length
              ? sanitize(row[creditIdx].toString())
              : "";

          if (debitVal.isNotEmpty) {
            amount = double.tryParse(debitVal) ?? 0;
            transactionType =
                AppConstants.transactionTypeWithdraw;
          } else if (creditVal.isNotEmpty) {
            amount = double.tryParse(creditVal) ?? 0;
            transactionType =
                AppConstants.transactionTypeDeposit;
          }
        } else if (hasAmountOnly) {
          final amountIdx = fieldIndexMap["amount"]!;
          if (amountIdx >= row.length) continue;

          final rawAmount =
              sanitize(row[amountIdx].toString());

          amount = double.tryParse(rawAmount) ?? 0;

          if (hasTypeColumn) {
            final typeIdx = fieldIndexMap["type"]!;
            if (typeIdx < row.length) {
              final typeVal = row[typeIdx]
                  .toString()
                  .toLowerCase()
                  .trim();

              if (typeVal.contains("cr")) {
                transactionType =
                    AppConstants.transactionTypeDeposit;
              } else {
                transactionType =
                    AppConstants.transactionTypeWithdraw;
              }
            }
          } else {
            if (rawAmount.startsWith("-")) {
              transactionType =
                  AppConstants.transactionTypeWithdraw;
              amount = amount.abs();
            } else {
              transactionType =
                  AppConstants.transactionTypeDeposit;
            }
          }
        }

        if (amount <= 0 ||
            amount.isNaN ||
            amount.isInfinite) {
          continue;
        }

        // ---------------------------
        // Date Parsing
        // ---------------------------
        DateTime timestamp = DateTime.now();

        if (hasDate) {
          final dateIdx = fieldIndexMap["date"]!;
          if (dateIdx < row.length) {
            final rawDate =
                row[dateIdx].toString().trim();
            if (rawDate.isNotEmpty) {
              timestamp = _parseDate(rawDate);
            }
          }
        }

        // ---------------------------
        // Semantic Classification
        // ---------------------------
        final semantic =
            TransactionSemanticClassifier
                .infer(rawDescription);

        final categoryId =
            expenseCategoryMap[
                    semantic.inferredCategoryName] ??
                expenseCategoryMap[
                    AppConstants.otherCategory];

        if (categoryId == null) continue;

        final documentId =
            "${timestamp.microsecondsSinceEpoch}_$amount";

        parsedExpenses.add({
          FirebaseConstants.documentIdField:
              documentId,
          FirebaseConstants.amountField: amount,
          FirebaseConstants.bankIdField:
              selectedBankId,
          FirebaseConstants.expenseField:
              semantic.inferredExpenseName,
          FirebaseConstants.expenseCategoryField:
              categoryId,
          FirebaseConstants.transactionTypeField:
              transactionType,
          FirebaseConstants.timestampField:
              timestamp,
          FirebaseConstants.isReminderCompletedField:
              false,
          FirebaseConstants.reminderRepetitionField:
              AppConstants.reminderOnce,
          FirebaseConstants.reminderTimeField:
              null,
        });
      } catch (_) {
        continue; // never crash per row
      }
    }

    return parsedExpenses;
  }

  // ---------------------------
  // Robust Date Parsing
  // ---------------------------
  DateTime _parseDate(String value) {
    final formats = [
      "dd/MM/yyyy",
      "d/M/yyyy",
      "MM/dd/yyyy",
      "yyyy-MM-dd",
      "dd-MM-yyyy",
      "d-M-yyyy",
      "yyyy/MM/dd",
      "dd MMM yyyy",
      "d MMM yyyy",
      "MMM dd yyyy",
      "dd.MM.yyyy",
      "yyyyMMdd",
      "dd/MM/yy",
      "MM/dd/yy",
      "yyyy.MM.dd",
      "dd-MMM-yyyy",
      "d-MMM-yyyy",
      "MMM-dd-yyyy",
      "yyyy/MM/dd HH:mm:ss",
      "dd/MM/yyyy HH:mm:ss",
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parseStrict(value);
      } catch (_) {}
    }

    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now(); // safe fallback
    }
  }
}
