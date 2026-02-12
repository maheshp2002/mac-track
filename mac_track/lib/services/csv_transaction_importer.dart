import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/utils/csv_importer.dart';

class CsvTransactionImporter {
  Future<List<Map<String, dynamic>>> importCsv({
    required String selectedBankId,
    required String salaryDocumentId, // ✅ REQUIRED
    required Map<String, String> expenseCategoryMap,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      return [];
    }

    final file = File(result.files.single.path!);
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
      if (descIdx >= row.length) continue;

      final description = row[descIdx].toString().trim();
      if (description.isEmpty) continue;

      double amount = 0;
      String transactionType = AppConstants.transactionTypeWithdraw;

      if (debitIdx != null &&
          debitIdx < row.length &&
          row[debitIdx].toString().isNotEmpty) {
        amount = double.tryParse(row[debitIdx].toString()) ?? 0;
      } else if (creditIdx != null &&
          creditIdx < row.length &&
          row[creditIdx].toString().isNotEmpty) {
        amount = double.tryParse(row[creditIdx].toString()) ?? 0;
        transactionType = AppConstants.transactionTypeDeposit;
      } else if (amountIdx != null && amountIdx < row.length) {
        amount = double.tryParse(row[amountIdx].toString()) ?? 0;
      }

      if (amount <= 0) continue;

      final semantic = CsvSemanticDictionary.infer(description);

      final categoryId = expenseCategoryMap[semantic.inferredCategoryName] ??
          expenseCategoryMap[AppConstants.otherCategory]!;

      // SAME document ID strategy as manual add
      final now = DateTime.now();
      final documentId = "${now.toIso8601String()}_$amount";

      parsedExpenses.add({
        FirebaseConstants.documentIdField: documentId,

        FirebaseConstants.amountField: amount,
        FirebaseConstants.bankIdField: selectedBankId,
        FirebaseConstants.expenseField: semantic.inferredExpenseName,
        FirebaseConstants.expenseCategoryField: categoryId,
        FirebaseConstants.transactionTypeField: transactionType,
        FirebaseConstants.timestampField: now,

        // REQUIRED FIELDS (missing earlier)
        FirebaseConstants.salaryDocumentIdField: salaryDocumentId,
        FirebaseConstants.isReminderCompletedField: false,
        FirebaseConstants.reminderRepetitionField: AppConstants.reminderOnce,
        FirebaseConstants.reminderTimeField: null,
      });
    }

    return parsedExpenses;
  }
}
