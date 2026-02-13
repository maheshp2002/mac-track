import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mac_track/config/constants.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> addData(
    String userEmail,
    String documentId,
    Map<String, dynamic> data,
    String collectionName,
  ) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName)
        .doc(documentId)
        .set(data);
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
    Map<String, dynamic> data,
    String collectionName,
  ) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName)
        .doc(documentId)
        .update(data);
  }

  Future<void> deleteExpenseData(
    String userEmail,
    String documentId,
    String collectionName,
  ) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName)
        .doc(documentId)
        .delete();
  }

  Future<void> updateDocumentFieldString(
    String? userEmail,
    String collectionName,
    String documentId,
    String fieldName,
    dynamic fieldValue,
  ) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(collectionName)
        .doc(documentId)
        .update({fieldName: fieldValue});
  }

  Future<void> addNotificationExpense({
    required double amount,
    required String type,
    required DateTime timestamp,
    required String userEmail,
  }) async {
    final expenseData = {
      FirebaseConstants.amountField: amount,
      FirebaseConstants.typeField: type,
      FirebaseConstants.bankIdField: "auto-detected",
      FirebaseConstants.timestampField: timestamp,
      FirebaseConstants.sourceField: "notification",
    };

    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(FirebaseConstants.expenseCollection)
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

  Future<void> addCounterparty({
    required String userEmail,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(FirebaseConstants.counterpartyCollection)
        .doc(documentId)
        .set(data);
  }

  Future<void> deleteCounterparty({
    required String userEmail,
    required String documentId,
  }) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userEmail)
        .collection(FirebaseConstants.counterpartyCollection)
        .doc(documentId)
        .delete();
  }
}
