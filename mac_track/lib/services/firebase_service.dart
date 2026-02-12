import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mac_track/config/constants.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double _balanceDelta({
    required String transactionType,
    required double amount,
  }) {
    switch (transactionType) {
      case AppConstants.transactionTypeDeposit:
        return amount;
      case AppConstants.transactionTypeWithdraw:
      case AppConstants.transactionTypeTransfer:
        return -amount;
      default:
        throw StateError('Unsupported transaction type: $transactionType');
    }
  }

  Future<double> _readSalaryAmount(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> salaryRef,
  ) async {
    final salarySnapshot = await transaction.get(salaryRef);
    if (!salarySnapshot.exists) {
      throw StateError('Salary record not found.');
    }
    return _asDouble(
        salarySnapshot.data()?[FirebaseConstants.currentAmountField]);
  }

  Stream<Map<String, dynamic>> streamBankData() {
    return _firestore
        .collection(FirebaseConstants.mastersCollection)
        .doc(FirebaseConstants.banksCollection)
        .collection(FirebaseConstants.banksCollection)
        .snapshots()
        .map((snapshot) {
      // Convert snapshot to a map of documents with their ID as keys
      snapshot.docs.map((doc) => doc.data()).toList();
      return {for (var doc in snapshot.docs) doc.id: doc.data()};
    });
  }

  Future<void> addData(String userEmail, String documentId,
      Map<String, dynamic> expenseData, String collectionName) async {
    // Reference to the user's expense collection
    CollectionReference expenseCollection = _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName);

    // Now add the actual expense document
    await expenseCollection.doc(documentId).set(expenseData);
  }

  Future<void> addExpenseWithSalaryUpdate({
    required String userEmail,
    required String salaryDocumentId,
    required String expenseDocumentId,
    required Map<String, dynamic> expenseData,
  }) async {
    final userRef =
        _firestore.collection(FirebaseConstants.usersCollection).doc(userEmail);
    final salaryRef = userRef
        .collection(FirebaseConstants.salaryCollection)
        .doc(salaryDocumentId);
    final expenseRef = userRef
        .collection(FirebaseConstants.expenseCollection)
        .doc(expenseDocumentId);

    await _firestore.runTransaction((transaction) async {
      final amount = _asDouble(expenseData[FirebaseConstants.amountField]);
      final transactionType =
          expenseData[FirebaseConstants.transactionTypeField] as String? ?? '';
      final delta =
          _balanceDelta(transactionType: transactionType, amount: amount);

      final currentAmount = await _readSalaryAmount(transaction, salaryRef);
      final updatedAmount = currentAmount + delta;
      if (updatedAmount < 0) {
        throw StateError('Insufficient balance in salary.');
      }

      transaction.update(salaryRef, {
        FirebaseConstants.currentAmountField: updatedAmount,
      });
      transaction.set(expenseRef, expenseData);
    });
  }

  Future<void> updateExpenseWithSalaryUpdate({
    required String userEmail,
    required String expenseDocumentId,
    required Map<String, dynamic> updatedExpenseData,
  }) async {
    final userRef =
        _firestore.collection(FirebaseConstants.usersCollection).doc(userEmail);
    final expenseRef = userRef
        .collection(FirebaseConstants.expenseCollection)
        .doc(expenseDocumentId);

    await _firestore.runTransaction((transaction) async {
      final expenseSnapshot = await transaction.get(expenseRef);
      if (!expenseSnapshot.exists) {
        throw StateError('Expense record not found.');
      }

      final existingExpense = expenseSnapshot.data() ?? {};
      final oldSalaryDocumentId =
          existingExpense[FirebaseConstants.salaryDocumentIdField] as String? ??
              '';
      final newSalaryDocumentId =
          updatedExpenseData[FirebaseConstants.salaryDocumentIdField]
                  as String? ??
              oldSalaryDocumentId;

      if (oldSalaryDocumentId.isEmpty || newSalaryDocumentId.isEmpty) {
        throw StateError('Salary record not found for this expense.');
      }

      final oldAmount =
          _asDouble(existingExpense[FirebaseConstants.amountField]);
      final newAmount =
          _asDouble(updatedExpenseData[FirebaseConstants.amountField]);
      final oldType =
          existingExpense[FirebaseConstants.transactionTypeField] as String? ??
              '';
      final newType = updatedExpenseData[FirebaseConstants.transactionTypeField]
              as String? ??
          '';

      final oldDelta =
          _balanceDelta(transactionType: oldType, amount: oldAmount);
      final newDelta =
          _balanceDelta(transactionType: newType, amount: newAmount);

      if (oldSalaryDocumentId == newSalaryDocumentId) {
        final salaryRef = userRef
            .collection(FirebaseConstants.salaryCollection)
            .doc(oldSalaryDocumentId);
        final currentAmount = await _readSalaryAmount(transaction, salaryRef);
        final updatedAmount = currentAmount - oldDelta + newDelta;

        if (updatedAmount < 0) {
          throw StateError('Insufficient balance in salary.');
        }

        transaction.update(salaryRef, {
          FirebaseConstants.currentAmountField: updatedAmount,
        });
      } else {
        final oldSalaryRef = userRef
            .collection(FirebaseConstants.salaryCollection)
            .doc(oldSalaryDocumentId);
        final newSalaryRef = userRef
            .collection(FirebaseConstants.salaryCollection)
            .doc(newSalaryDocumentId);

        final oldCurrentAmount =
            await _readSalaryAmount(transaction, oldSalaryRef);
        final newCurrentAmount =
            await _readSalaryAmount(transaction, newSalaryRef);

        final oldUpdatedAmount = oldCurrentAmount - oldDelta;
        final newUpdatedAmount = newCurrentAmount + newDelta;

        if (oldUpdatedAmount < 0 || newUpdatedAmount < 0) {
          throw StateError('Insufficient balance in salary.');
        }

        transaction.update(oldSalaryRef, {
          FirebaseConstants.currentAmountField: oldUpdatedAmount,
        });
        transaction.update(newSalaryRef, {
          FirebaseConstants.currentAmountField: newUpdatedAmount,
        });
      }

      transaction.update(expenseRef, updatedExpenseData);
    });
  }

  Future<void> deleteExpenseWithSalaryUpdate({
    required String userEmail,
    required String expenseDocumentId,
  }) async {
    final userRef =
        _firestore.collection(FirebaseConstants.usersCollection).doc(userEmail);
    final expenseRef = userRef
        .collection(FirebaseConstants.expenseCollection)
        .doc(expenseDocumentId);

    await _firestore.runTransaction((transaction) async {
      final expenseSnapshot = await transaction.get(expenseRef);
      if (!expenseSnapshot.exists) {
        return;
      }

      final expenseData = expenseSnapshot.data() ?? {};
      final salaryDocumentId =
          expenseData[FirebaseConstants.salaryDocumentIdField] as String? ?? '';
      if (salaryDocumentId.isEmpty) {
        throw StateError('Salary record not found for this expense.');
      }

      final amount = _asDouble(expenseData[FirebaseConstants.amountField]);
      final transactionType =
          expenseData[FirebaseConstants.transactionTypeField] as String? ?? '';
      final delta =
          _balanceDelta(transactionType: transactionType, amount: amount);

      final salaryRef = userRef
          .collection(FirebaseConstants.salaryCollection)
          .doc(salaryDocumentId);
      final currentAmount = await _readSalaryAmount(transaction, salaryRef);
      final updatedAmount = currentAmount - delta;

      if (updatedAmount < 0) {
        throw StateError('Insufficient balance in salary.');
      }

      transaction.update(salaryRef, {
        FirebaseConstants.currentAmountField: updatedAmount,
      });
      transaction.delete(expenseRef);
    });
  }

  Future<void> importExpensesWithSalaryUpdate({
    required String userEmail,
    required String salaryDocumentId,
    required List<Map<String, dynamic>> expenses,
  }) async {
    if (expenses.isEmpty) return;
    if (expenses.length > 499) {
      throw StateError('CSV import supports up to 499 transactions at a time.');
    }

    final userRef =
        _firestore.collection(FirebaseConstants.usersCollection).doc(userEmail);
    final salaryRef = userRef
        .collection(FirebaseConstants.salaryCollection)
        .doc(salaryDocumentId);

    await _firestore.runTransaction((transaction) async {
      var currentAmount = await _readSalaryAmount(transaction, salaryRef);

      for (final expense in expenses) {
        final amount = _asDouble(expense[FirebaseConstants.amountField]);
        final transactionType =
            expense[FirebaseConstants.transactionTypeField] as String? ?? '';
        final delta =
            _balanceDelta(transactionType: transactionType, amount: amount);
        final updatedAmount = currentAmount + delta;

        if (updatedAmount < 0) {
          throw StateError('Insufficient balance in salary.');
        }

        final expenseId =
            expense[FirebaseConstants.documentIdField] as String? ?? '';
        if (expenseId.isEmpty) {
          throw StateError('Invalid imported expense id.');
        }

        final expenseRef = userRef
            .collection(FirebaseConstants.expenseCollection)
            .doc(expenseId);
        transaction.set(expenseRef, expense);
        currentAmount = updatedAmount;
      }

      transaction.update(salaryRef, {
        FirebaseConstants.currentAmountField: currentAmount,
      });
    });
  }

  Stream<Map<String, dynamic>> streamGetAllData(
      String userEmail, String collectionName) {
    return _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName)
        .snapshots()
        .map((snapshot) {
      // Convert snapshot to a map of documents with their ID as keys
      snapshot.docs.map((doc) => doc.data()).toList();
      return {for (var doc in snapshot.docs) doc.id: doc.data()};
    });
  }

  Stream<Map<String, dynamic>> streamUserBankData(
      String userEmail, String collectionName) {
    return _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName)
        .snapshots()
        .map((snapshot) {
      // Convert snapshot to a map of documents with their ID as keys
      snapshot.docs.map((doc) => doc.data()).toList();
      return {for (var doc in snapshot.docs) doc.id: doc.data()};
    });
  }

  // Update the salary amount in the salary document
  Future<void> updateSalaryAmount(
      String? userEmail, String documentId, double newAmount) async {
    await FirebaseFirestore.instance
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(FirebaseConstants.salaryCollection)
        .doc(documentId)
        .update({FirebaseConstants.currentAmountField: newAmount});
  }

  Stream<Map<String, dynamic>> streamExpenseTypes() {
    return _firestore
        .collection(FirebaseConstants.mastersCollection)
        .doc(FirebaseConstants.expenseTypesCollection)
        .collection(FirebaseConstants.expenseTypesCollection)
        .snapshots()
        .map((snapshot) {
      return {
        for (var doc in snapshot.docs) doc.id: doc.data(),
      };
    });
  }

  // Get the data based on document id
  Stream<Map<String, dynamic>> streamGetDataInUserById(
    String userEmail,
    String collectionName,
    String documentId,
  ) {
    return _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName)
        .doc(documentId)
        .snapshots()
        .map((snapshot) => snapshot.data() ?? {});
  }

  Future<void> updatedExpenseData(
    String userEmail,
    String documentId,
    Map<String, dynamic> expenseData,
    String collectionName,
  ) async {
    CollectionReference expenseCollection = _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName);

    await expenseCollection.doc(documentId).update(expenseData);
  }

  Future<void> deleteExpenseData(
    String userEmail,
    String documentId,
    String collectionName,
  ) async {
    CollectionReference expenseCollection = _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName);

    await expenseCollection.doc(documentId).delete();
  }

  // Update the salary amount in the salary document
  Future<void> updateDocumentFieldString(
      String? userEmail,
      String collectionName,
      String documentId,
      String filedName,
      filedValue) async {
    await FirebaseFirestore.instance
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName)
        .doc(documentId)
        .update({filedName: filedValue});
  }

  Future<void> addNotificationExpense({
    required double amount,
    required String type,
    required DateTime timestamp,
    required String userEmail,
  }) async {
    final expenseData = {
      "amount": amount,
      "type": type,
      "bankId": "auto-detected",
      "timestamp": timestamp,
      "source": "notification",
    };

    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection("expense")
        .add(expenseData);
  }

  Stream<Map<String, dynamic>> streamGetAllDataForReport(
      String userEmail, String collectionName) {
    return _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName)
        .snapshots()
        .map((snapshot) {
      return {for (var doc in snapshot.docs) doc.id: doc.data()};
    });
  }
}
