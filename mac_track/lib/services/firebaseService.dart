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

  Future<void> addExpense(String userEmail, String documentId, Map<String, dynamic> expenseData) async {
    // Reference to the user's expense collection
    CollectionReference expenseCollection = _firestore
        .collection('users')
        .doc(userEmail)
        .collection('expense');

    // Check if the collection is empty
    QuerySnapshot snapshot = await expenseCollection.get();
    if (snapshot.docs.isEmpty) {
      // If no documents exist, create a dummy document to initialize the collection
      await expenseCollection.doc('init').set({'initialized': true});
    }

    // Now add the actual expense document
    await expenseCollection.doc(documentId).set(expenseData);
  }
}
