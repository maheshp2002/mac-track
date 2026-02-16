class AppConstants {
  static const String otherCategory = 'Other';
  static const String addNewBankLabel = 'Add New Bank';
  static const String transactionTypeWithdraw = 'Withdraw';
  static const String transactionTypeDeposit = 'Deposit';
  static const String transactionTypeTransfer = 'Transfer';
  static const String refresh = 'refresh';
  static const String allItem = 'All';
  static const String reminderOnce = 'Once';
  static const String reminderDaily = 'Daily';
  static const String reminderWeekly = 'Weekly';
  static const String reminderMonthly = 'Monthly';
  static const String reminderYearly = 'Yearly';
  static const String reminderCustom = 'Custom';
  static const String transaction = 'Transaction';
  static const String balance = 'Balance';
  static const String englishIndiaLocale = 'en_IN';
  static const String rupeesSymbol = '₹';
  static const String manualToggle= 'Manual';
  static const String csvToggle = 'CSV';
  static const String salaryCategory = 'Salary';
}

class FirebaseConstants {
  // Firebase Collections
  static const String userBankCollection = 'userBanks';
  static const String expenseCollection = 'expense';
  static const String banksCollection = 'banks';
  static const String mastersCollection = 'masters';
  static const String usersCollection = 'users';
  static const String expenseTypesCollection = 'expenseTypes';
  static const String counterpartyCollection = 'counterparties';

  //Firebase Fields
  static const String primaryIdField = 'id';
  static const String nameField = 'name';
  static const String amountField = 'amount';
  static const String documentIdField = 'documentId';
  static const String bankIdField = 'bankId';
  static const String expenseField = 'expense';
  static const String timestampField = 'timestamp';
  static const String expenseCategoryField = 'expenseCategory';
  static const String transactionTypeField = 'transactionType';
  static const String bankNameField = 'bankName';
  static const String isPrimaryField = 'isPrimary';
  static const String totalAmountField = 'totalAmount';
  static const String reminderRepetitionField = "reminderRepetition";
  static const String reminderTimeField = "reminderTime";
  static const String isReminder = "isReminder";
  static const String isReminderCompletedField = "isReminderCompleted";
  static const String imageField = 'image';
  static const String typeField = 'type';
  static const String sourceField = 'source';
  static const String counterpartyIdField = 'counterpartyId';
  static const String counterpartyNameField = 'counterpartyName';
  static const String updatedAtField = 'updatedAt';
}
