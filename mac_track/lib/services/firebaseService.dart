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
    return {
      for (var doc in snapshot.docs)
        doc.id: doc.data()
    };
  });
}

}
