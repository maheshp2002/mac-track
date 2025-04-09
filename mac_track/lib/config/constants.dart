class AppConstants {
  static const String expenseCategoryOther = 'Other';
  static const String addNewBankLabel = 'Add New Bank';
  static const String transactionTypeWithdraw = 'Withdraw';
  static const String transactionTypeDeposit = 'Deposit';
  static const String transactionTypeTransfer = 'Transfer';
  static const String refresh = 'refresh';
}

class FirebaseConstants {
  // Firebase Collections
  static const String userBankCollection = 'userBanks';
  static const String salaryCollection = 'salary';
  static const String expenseCollection = 'expense';
  static const String banksCollection = 'banks';
  static const String mastersCollection = 'masters';
  static const String usersCollection = 'users';
  static const String expenseTypesCollection = 'expenseTypes';

  //Firebase Fields
  static const String amountField = 'amount';
  static const String documentIdField = 'documentId';
  static const String currentAmountField = 'currentAmount';
  static const String bankIdField = 'bankId';
  static const String expenseField = 'expense';
  static const String salaryDocumentIdField = 'salaryDocumentId';
  static const String timestampField = 'timestamp';
  static const String expenseCategoryField = 'expenseCategory';
  static const String transactionTypeField = 'transactionType';
}
