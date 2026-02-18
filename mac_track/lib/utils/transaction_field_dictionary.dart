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
    "type": [
      "type",
      "transaction type",
      "dr/cr",
      "cr/dr",
      "indicator"
    ]
  };

  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? detectField(String header) {
    final normalized = normalize(header);

    String? bestMatch;
    int bestScore = 0;

    for (final entry in fieldAliases.entries) {
      for (final alias in entry.value) {
        final normAlias = normalize(alias);

        int score = 0;

        if (normalized == normAlias) {
          score = 3;
        } else if (normalized.startsWith(normAlias)) {
          score = 2;
        } else if (normalized.contains(normAlias)) {
          score = 1;
        }

        if (score > bestScore) {
          bestScore = score;
          bestMatch = entry.key;
        }
      }
    }

    return bestScore > 0 ? bestMatch : null;
  }
}
