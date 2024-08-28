import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<Map<String, dynamic>> streamBankData() {
    return _firestore
        .collection('masters') // Collection under which 'banks' is located
        .doc('banks') // Document which holds 'banks' collection
        .collection('banks') // The collection you are interested in
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
        .collection('users')
        .doc(userEmail)
        .collection(collectionName);

    // Now add the actual expense document
    await expenseCollection.doc(documentId).set(expenseData);
  }

  Stream<Map<String, dynamic>> streamGetAllData(
      String userEmail, String collectionName) {
    return _firestore
        .collection('users')
        .doc(userEmail)
        .collection(collectionName)
        .snapshots()
        .map((snapshot) {
      // Convert snapshot to a map of documents with their ID as keys
      snapshot.docs.map((doc) => doc.data()).toList();
      return {for (var doc in snapshot.docs) doc.id: doc.data()};
    });
  }
}
