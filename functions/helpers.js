// =================================================================================================
// [ helpers.js ] - 다른 파일들이 공통으로 사용하는 헬퍼 함수 모음
// =================================================================================================

const admin = require("firebase-admin");
const functions = require("firebase-functions"); // v1 로거 사용 시 필요

// db 인스턴스를 여기서도 선언
const db = admin.firestore();

// =================================================================================================
// 헬퍼 함수 (Helper Functions)
// =================================================================================================

/**
 * ✅ [추가] FCM 푸시 알림만 전송합니다. (Firestore에 저장하지 않음)
 * 주로 반복적인 자동 알림에 사용됩니다. (scheduled.js에서 사용)
 * @param {string} title - 알림 제목.
 * @param {string} message - 알림 내용.
 */
const sendPushNotificationOnly = async (title, message) => {
  try {
    await admin.messaging().send({
      topic: "all",
      notification: { title, body: message },
      apns: { payload: { aps: { alert: { title, body: message }, sound: "default", badge: 1 } } },
      data: { screen: "UserNotificationPage" },
    });
    console.log(`FCM 푸시 알림만 전송 성공: "${title}"`);
  } catch (error) {
    console.error("FCM 푸시 알림만 전송 실패:", error);
  }
};


/**
 * FCM 푸시 알림을 보내고, 모든 사용자의 Firestore에도 알림을 저장합니다.
 * 주로 관리자가 보내는 전체 공지에 사용됩니다. (callable.js에서 사용)
 * @param {string} title - 알림 제목.
 * @param {string} message - 알림 내용.
 */
const sendNotificationToUsers = async (title, message) => {
  const timestamp = admin.firestore.Timestamp.now();

  try {
    await admin.messaging().send({
      topic: "all",
      notification: { title, body: message },
      apns: { payload: { aps: { alert: { title, body: message }, sound: "default", badge: 1 } } },
      data: { screen: "UserNotificationPage" },
    });
    console.log("FCM 메시지 전송 성공.");
  } catch (error) {
    console.error("FCM 메시지 전송 실패:", error);
  }

  try {
    const usersSnapshot = await admin.firestore().collection("users").get();
    if (usersSnapshot.empty) {
      console.log("알림을 저장할 사용자가 없습니다.");
      return;
    }
    const batch = admin.firestore().batch();
    usersSnapshot.forEach(userDoc => {
      const email = userDoc.id;
      if (!email) return;
      const docRef = admin.firestore().collection("notifications").doc(email).collection("items").doc();
      batch.set(docRef, { title, message, timestamp, isRead: false });
    });
    await batch.commit();
    console.log(`Firestore에 ${usersSnapshot.size}명의 사용자에게 알림 저장 완료.`);
  } catch (error) {
    console.error("Firestore에 알림 저장 실패:", error);
  }
};

/**
 * 쿼리 결과를 바탕으로 문서를 500개 단위의 배치로 나누어 삭제합니다.
 * (callable.js, scheduled.js에서 사용)
 * @param {FirebaseFirestore.QuerySnapshot | FirebaseFirestore.QueryDocumentSnapshot[]} snapshotOrDocs - 삭제할 문서들의 쿼리 스냅샷 또는 문서 배열.
 * @param {FirebaseFirestore.Firestore} firestore - Firestore 인스턴스.
 */
const deleteDocumentsInBatch = async (snapshotOrDocs, firestore) => {
  const docs = Array.isArray(snapshotOrDocs) ? snapshotOrDocs : snapshotOrDocs.docs;
  const size = Array.isArray(snapshotOrDocs) ? snapshotOrDocs.length : snapshotOrDocs.size;

  if (size === 0) {
    return 0; // 삭제할 문서가 없으면 0 반환
  }

  const batchSize = 500; // Firestore batch limit
  let batch = firestore.batch();
  let count = 0;
  let deletedCount = 0;

  for (const doc of docs) {
    batch.delete(doc.ref);
    count++;
    deletedCount++;
    if (count === batchSize) {
      // Commit the batch and start a new one
      await batch.commit();
      batch = firestore.batch();
      count = 0;
    }
  }

  // Commit the remaining documents
  if (count > 0) {
    await batch.commit();
  }

  return deletedCount; // 삭제된 문서 수 반환
};

/**
 * 지정된 경로의 컬렉션 또는 하위 컬렉션의 모든 문서를 삭제합니다.
 * (callable.js, scheduled.js에서 사용)
 * @param {FirebaseFirestore.Firestore} db - Firestore 인스턴스.
 * @param {string} collectionPath - 삭제할 컬렉션 경로.
 * @param {number} batchSize - 배치 크기 (기본값 500).
 */
async function deleteCollection(db, collectionPath, batchSize = 500) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.orderBy('__name__').limit(batchSize); // 문서 ID 기준 정렬 및 제한

  return new Promise((resolve, reject) => {
    deleteQueryBatch(db, query, resolve).catch(reject);
  });
}

/**
 * 쿼리 결과를 배치로 나누어 삭제하는 재귀 함수입니다. deleteCollection 내부에서 사용됩니다.
 * @param {FirebaseFirestore.Firestore} db - Firestore 인스턴스.
 * @param {FirebaseFirestore.Query} query - 삭제할 문서 쿼리.
 * @param {Function} resolve - Promise resolve 함수.
 */
async function deleteQueryBatch(db, query, resolve) {
  const snapshot = await query.get();

  const batchSize = snapshot.size;
  if (batchSize === 0) {
    // 삭제할 문서가 더 이상 없으면 완료
    resolve();
    return;
  }

  // 문서를 배치로 삭제
  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  // 스택 오버플로우를 피하기 위해 다음 틱에서 재귀 호출
  process.nextTick(() => {
    deleteQueryBatch(db, query, resolve);
  });
}

// --- 3. 정의한 헬퍼 함수들을 내보내기(export) ---
module.exports = {
  sendPushNotificationOnly,
  sendNotificationToUsers,
  deleteDocumentsInBatch,
  deleteCollection,
  deleteQueryBatch,
};