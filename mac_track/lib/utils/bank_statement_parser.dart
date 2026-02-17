import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'transaction_field_dictionary.dart';

class BankTransaction {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String reference;

  BankTransaction({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.reference,
  });
}

class BankStatementParser {
  Future<List<BankTransaction>> parseFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();

    if (extension == "csv") {
      final content = await file.readAsString();
      return _parseCsv(content);
    } else if (extension == "xlsx") {
      final bytes = await file.readAsBytes();
      return _parseExcel(bytes);
    } else {
      throw UnsupportedError("Unsupported file type");
    }
  }

  Future<List<BankTransaction>> _parseCsv(String content) async {
    final rows = CsvCodec().decoder.convert(content);
    return _processRows(rows);
  }


  Future<List<BankTransaction>> _parseExcel(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) return [];

    final sheet = excel.tables.values.first;

    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value).toList())
        .toList();

    return _processRows(rows);
  }

  List<BankTransaction> _processRows(List<List<dynamic>> rows) {
    if (rows.length < 2) return [];

    final headerRow = rows.first;
    final fieldMap = <int, String>{};

    for (int i = 0; i < headerRow.length; i++) {
      final header = headerRow[i]?.toString() ?? "";
      final detected = TransactionFieldDictionary.detectField(header);
      if (detected != null) {
        fieldMap[i] = detected;
      }
    }

    final transactions = <BankTransaction>[];

    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      try {
        DateTime date = DateTime.now();
        String description = "";
        double debit = 0;
        double credit = 0;
        double balance = 0;
        String reference = "";

        for (int i = 0; i < row.length; i++) {
          if (!fieldMap.containsKey(i)) continue;

          final field = fieldMap[i];
          final value = row[i]?.toString().trim() ?? "";

          if (value.isEmpty) continue;

          switch (field) {
            case "date":
              date = _parseDate(value);
              break;
            case "description":
              description = value;
              break;
            case "debit":
              debit = _parseAmount(value);
              break;
            case "credit":
              credit = _parseAmount(value);
              break;
            case "amount":
              final amt = _parseAmount(value);
              if (amt < 0) {
                debit = amt.abs();
              } else {
                credit = amt;
              }
              break;
            case "balance":
              balance = _parseAmount(value);
              break;
            case "reference":
              reference = value;
              break;
          }
        }

        // Skip useless rows
        if (description.isEmpty) continue;
        if (debit <= 0 && credit <= 0) continue;

        transactions.add(
          BankTransaction(
            date: date,
            description: description,
            debit: debit,
            credit: credit,
            balance: balance,
            reference: reference,
          ),
        );
      } catch (_) {
        continue; // Never crash on bad row
      }
    }

    return transactions;
  }

  double _parseAmount(String value) {
    try {
      final cleaned = value
          .replaceAll(",", "")
          .replaceAll("₹", "")
          .replaceAll("INR", "")
          .replaceAll(RegExp(r'[^\d\.\-]'), "");

      return double.tryParse(cleaned) ?? 0;
    } catch (_) {
      return 0;
    }
  }

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
