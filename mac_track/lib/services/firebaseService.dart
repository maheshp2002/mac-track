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
}
