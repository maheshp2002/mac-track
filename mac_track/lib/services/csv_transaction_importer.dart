import 'dart:io';
import 'package:csv/csv.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/utils/csv_importer.dart';

class CsvTransactionImporter {    
  Future<List<Map<String, dynamic>>> importCsv({
    required String filePath,
    required String selectedBankId,
    required Map<String, String> expenseCategoryMap,
  }) async {

    final file = File(filePath);
    final content = await file.readAsString();

    final List<List<dynamic>> rows = CsvCodec().decoder.convert(content);

    if (rows.length < 2) {
      throw Exception('CSV has no transaction rows');
    }

    final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();

    int? descIdx, debitIdx, creditIdx, amountIdx;

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (descIdx == null &&
          (h.contains('description') ||
              h.contains('narration') ||
              h.contains('desc'))) {
        descIdx = i;
      }
      if (debitIdx == null && h.contains('debit')) debitIdx = i;
      if (creditIdx == null && h.contains('credit')) creditIdx = i;
      if (amountIdx == null && h.contains('amount')) amountIdx = i;
    }

    if (descIdx == null) {
      throw Exception('Unable to identify description column');
    }

    final List<Map<String, dynamic>> parsedExpenses = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      if (row.isEmpty || descIdx >= row.length) continue;

      final rawDescription = row[descIdx].toString().trim();
      if (rawDescription.isEmpty || rawDescription.length < 2) continue;

      double amount = 0;
      String transactionType = AppConstants.transactionTypeWithdraw;

      String sanitize(String value) =>
          value.replaceAll(',', '').replaceAll('₹', '').trim();

      try {
        if (debitIdx != null &&
            debitIdx < row.length &&
            row[debitIdx].toString().trim().isNotEmpty) {
          amount = double.tryParse(sanitize(row[debitIdx].toString())) ?? 0;
          transactionType = AppConstants.transactionTypeWithdraw;
        } else if (creditIdx != null &&
            creditIdx < row.length &&
            row[creditIdx].toString().trim().isNotEmpty) {
          amount = double.tryParse(sanitize(row[creditIdx].toString())) ?? 0;
          transactionType = AppConstants.transactionTypeDeposit;
        } else if (amountIdx != null && amountIdx < row.length) {
          amount = double.tryParse(sanitize(row[amountIdx].toString())) ?? 0;
        }
      } catch (_) {
        continue;
      }

      if (amount <= 0 || amount.isNaN || amount.isInfinite) continue;

      final semantic = CsvSemanticDictionary.infer(rawDescription);

      final categoryId = expenseCategoryMap[semantic.inferredCategoryName] ??
          expenseCategoryMap[AppConstants.otherCategory];

      if (categoryId == null) continue;

      final now = DateTime.now();
      final documentId = "${now.microsecondsSinceEpoch}_$amount";

      parsedExpenses.add({
        FirebaseConstants.documentIdField: documentId,
        FirebaseConstants.amountField: amount,
        FirebaseConstants.bankIdField: selectedBankId,
        FirebaseConstants.expenseField: semantic.inferredExpenseName,
        FirebaseConstants.expenseCategoryField: categoryId,
        FirebaseConstants.transactionTypeField: transactionType,
        FirebaseConstants.timestampField: now,
        FirebaseConstants.isReminderCompletedField: false,
        FirebaseConstants.reminderRepetitionField: AppConstants.reminderOnce,
        FirebaseConstants.reminderTimeField: null,
      });
    }

    return parsedExpenses;
  }
}
