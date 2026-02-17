class TransactionFieldDictionary {
  static const Map<String, List<String>> fieldAliases = {
    "date": [
      "date",
      "transaction date",
      "txn date",
      "tran date",
      "value date",
      "val date",
      "posting date",
      "post date",
      "dt",
      "txndate",
      "transaction_dt",
      "trn date",
      "entry date",
      "effective date",
      "process date"
    ],
    "description": [
      "description",
      "narration",
      "remarks",
      "remark",
      "details",
      "particulars",
      "transaction details",
      "transaction description",
      "txn description",
      "txn details",
      "narr",
      "nar",
      "info",
      "transaction info",
      "ref details",
      "reference details",
      "comment",
      "comments"
    ],
    "debit": [
      "debit",
      "withdrawal",
      "withdraw",
      "dr",
      "debit amount",
      "withdrawal amt",
      "withdrawal amount",
      "dr amount",
      "debit amt",
      "dpst out",
      "outflow"
    ],
    "credit": [
      "credit",
      "deposit",
      "cr",
      "credit amount",
      "deposit amt",
      "deposit amount",
      "cr amount",
      "dpst",
      "inflow",
      "received"
    ],
    "amount": [
      "amount",
      "txn amount",
      "transaction amount",
      "amt",
      "transaction amt",
      "value",
      "total amount",
      "net amount"
    ],
    "balance": [
      "balance",
      "available balance",
      "closing balance",
      "running balance",
      "bal",
      "avail bal",
      "cl bal",
      "ledger balance",
      "account balance"
    ],
    "reference": [
      "reference",
      "ref no",
      "reference no",
      "ref number",
      "utr",
      "utr no",
      "transaction id",
      "txn id",
      "transaction ref",
      "cheque no",
      "chq no",
      "cheque number"
    ],
  };

  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();
  }

  static String? detectField(String header) {
    final normalized = normalize(header);

    for (final entry in fieldAliases.entries) {
      for (final alias in entry.value) {
        if (normalized == normalize(alias)) {
          return entry.key;
        }
      }
    }
    return null;
  }
}
