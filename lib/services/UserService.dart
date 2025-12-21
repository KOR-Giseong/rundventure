import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 특정 컬렉션의 모든 문서 삭제
  Future<void> deleteAllUsers() async {
    final CollectionReference usersCollection = _firestore.collection('users');
    final QuerySnapshot snapshot = await usersCollection.get();

    for (final QueryDocumentSnapshot doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // 배치 삭제 방법
  Future<void> deleteUsersInBatch() async {
    final WriteBatch batch = _firestore.batch();
    final CollectionReference usersCollection = _firestore.collection('users');
    final QuerySnapshot snapshot = await usersCollection.get();

    for (final QueryDocumentSnapshot doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}