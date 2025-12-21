// [전체 코드] callable.js

// =================================================================================================
// [ callable.js ] - 앱에서 직접 호출하는 함수 (onCall) 모음
// =================================================================================================

// --- 1. 필요한 모듈 임포트 ---
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const functions = require("firebase-functions");

// --- 2. 헬퍼 함수 임포트 (Part 1에서 만듦) ---
const {
  sendNotificationToUsers,
  deleteDocumentsInBatch,
  deleteCollection, // ⭐️ eventChallenges 삭제 시 사용
} = require("./helpers.js");

// --- 3. 전역 인스턴스 및 상수 ---
const rtdb = admin.database();
const db = admin.firestore();
const SUPER_ADMIN_EMAIL = process.env.SUPERADMIN_EMAIL;


// =================================================================================================
// 호출 가능 함수 (Callable Functions)
// =================================================================================================
// (주의: 여기서는 'exports.'를 붙이지 않고, 맨 마지막에 module.exports로 한번에 내보냅니다.)

// (1)
const deleteUserAccount = onCall({ region: "us-central1", timeoutSeconds: 540, memory: "1GiB" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "함수를 호출하려면 인증이 필요합니다.");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email;
  const firestore = admin.firestore();

  if (!uid || !email) {
    throw new HttpsError("invalid-argument", "사용자 인증 정보가 올바르지 않습니다.");
  }

  functions.logger.info(`[시작] 계정 삭제 요청: UID=${uid}, Email=${email}`);

  try {
    const userDocRef = firestore.collection("users").doc(email);
    const userDocSnapshot = await userDocRef.get();
    let userNickname = null;
    if (userDocSnapshot.exists) {
      userNickname = userDocSnapshot.data()?.nickname;
    } else {
      functions.logger.warn(`Firestore users 문서 없음: ${email}`);
    }

    // --- 0. [신규] 채팅방 삭제를 위해 친구 목록 미리 조회 ---
    functions.logger.info(`[진행] ${email} 사용자의 친구 목록 조회 (채팅방 삭제용)`);
    const friendsSnapshot = await firestore.collection(`users/${email}/friends`).get();
    const friendEmails = friendsSnapshot.docs.map(doc => doc.id);
    functions.logger.info(` - ${friendEmails.length}명의 친구 확인.`);
    // --- [신규] 조회 완료 ---


    // --- 1. Delete Firestore Subcollections FIRST ---
    functions.logger.info(`[진행] ${email} 사용자의 하위 컬렉션 삭제 시작`);
    const subCollectionsPaths = [
      `users/${email}/activeQuests`,
      `users/${email}/completedQuestsLog`,
      // ▼▼▼▼▼ [친구 기능] 1. 계정 삭제 시 친구 관련 데이터 삭제 ▼▼▼▼▼
      `users/${email}/friends`, // 내 친구 목록
      `users/${email}/friendRequests`, // 내가 받은 친구 요청
      // ▲▲▲▲▲ [친구 기능] 1. 계정 삭제 시 친구 관련 데이터 삭제 ▲▲▲▲▲
      `notifications/${email}/items`,
      `ghostRunRecords/${email}/records`,
      `userRunningGoals/${email}/dailyGoals`,
      `userRunningData/${email}/goals`,
      `userRunningData/${email}/workouts`
    ];
    const workoutsSnapshot = await firestore.collection(`userRunningData/${email}/workouts`).get();
    if (!workoutsSnapshot.empty) {
      functions.logger.info(` - userRunningData/${email}/workouts 하위의 'records' 컬렉션 ${workoutsSnapshot.size}개 삭제 시작...`);
      for (const workoutDoc of workoutsSnapshot.docs) {
        subCollectionsPaths.push(`userRunningData/${email}/workouts/${workoutDoc.id}/records`);
      }
    }
    const deletionPromises = subCollectionsPaths.map(path => {
      functions.logger.info(` - ${path} 컬렉션 삭제 중...`);
      return deleteCollection(firestore, path, 500)
        .then(() => functions.logger.info(` - ${path} 컬렉션 삭제 완료.`))
        .catch(err => functions.logger.error(` - ${path} 컬렉션 삭제 중 오류:`, err));
    });
    await Promise.all(deletionPromises);
    functions.logger.info(`[성공] 개인 Firestore 데이터 (하위 컬렉션) 삭제 완료: ${email}`);


    // --- 2. Delete Top-Level Documents ---
    functions.logger.info(`[진행] ${email} 사용자의 최상위 문서 삭제 시작`);
    const personalDataBatch = firestore.batch();
    if (userNickname && userNickname.length > 0) {
      const nicknameDocRef = firestore.collection("nicknames").doc(userNickname.toLowerCase());
      const nicknameDoc = await nicknameDocRef.get();
      if (nicknameDoc.exists) {
        personalDataBatch.delete(nicknameDocRef);
      } else {
        functions.logger.warn(`Firestore nicknames 문서 없음: ${userNickname.toLowerCase()}`);
      }
    }
    if (userDocSnapshot.exists) {
      personalDataBatch.delete(userDocRef);
    }
    const collectionsToDelete = ["userRunningData", "userRunningGoals", "ghostRunRecords", "notifications"];
    const docExistenceChecks = collectionsToDelete.map(async (collectionName) => {
      const docRef = firestore.collection(collectionName).doc(email);
      const docSnapshot = await docRef.get();
      return { docRef, exists: docSnapshot.exists };
    });
    const results = await Promise.all(docExistenceChecks);
    results.forEach(({ docRef, exists }) => {
      if (exists) {
        personalDataBatch.delete(docRef);
      } else {
        functions.logger.warn(`Firestore ${docRef.path} 문서 없음.`);
      }
    });
    await personalDataBatch.commit();
    functions.logger.info(`[성공] 개인 Firestore 데이터 (최상위 문서) 삭제 완료: ${email}`);


    // --- 3. Delete User-Generated Content (Posts, Challenges, Comments) ---
    functions.logger.info(`[진행] ${email} 사용자가 작성한 게시물, 챌린지, 댓글, 채팅방 등 삭제 시작`);
    const contentDeletionPromises = [];

    // 자유게시판 글 삭제 (유저가 생성한)
    const freeTalksQuery = firestore.collection("freeTalks").where("userEmail", "==", email);
    contentDeletionPromises.push(freeTalksQuery.get().then(snapshot => {
      return deleteDocumentsInBatch(snapshot, firestore).then(count =>
        functions.logger.info(` - ${count}개의 자유게시판 게시물 삭제 완료.`)
      );
    }).catch(err => functions.logger.error("자유게시판 게시물 삭제 중 오류:", err)));

    // 챌린지 글 삭제 (유저가 생성한)
    const challengesQuery = firestore.collection("challenges").where("userEmail", "==", email);
    contentDeletionPromises.push(challengesQuery.get().then(snapshot => {
      return deleteDocumentsInBatch(snapshot, firestore).then(count =>
        functions.logger.info(` - ${count}개의 챌린지 게시물 삭제 완료.`)
      );
    }).catch(err => functions.logger.error("챌린지 게시물 삭제 중 오류:", err)));

    // 댓글 삭제 (Collection Group)
    const commentsQuery = firestore.collectionGroup("comments").where("userEmail", "==", email);
    contentDeletionPromises.push(commentsQuery.get().then(snapshot => {
      return deleteDocumentsInBatch(snapshot, firestore).then(count =>
        functions.logger.info(` - 총 ${count}개의 댓글 삭제 완료.`)
      );
    }).catch(err => {
      functions.logger.error("댓글 삭제 중 오류:", err);
      if (err.code === 'failed-precondition') {
        functions.logger.error("댓글 삭제를 위한 Firestore 색인이 필요할 수 있습니다.");
      }
    }));

    // 🔥🔥🔥 [신규 추가] 사용자가 '참여'한 챌린지 목록에서 해당 사용자 제거 🔥🔥🔥
    const participationQuery = firestore.collection("challenges").where("participants", "array-contains", email);
    contentDeletionPromises.push(participationQuery.get().then(async (snapshot) => {
      if (snapshot.empty) {
        functions.logger.info(" - 사용자가 참여한 챌린지가 없습니다.");
        return 0;
      }

      let batch = firestore.batch();
      let count = 0;
      const batchSize = 500; // Batch size limit

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const newParticipantMap = data.participantMap || {};

        // participantMap에서 사용자 이메일 키(예: "ghdrltjd0423@naver.com") 제거
        // 이 방식은 이메일에 '.'이 있어도 안전합니다.
        delete newParticipantMap[email];

        batch.update(doc.ref, {
          "participants": admin.firestore.FieldValue.arrayRemove(email),
          "participantMap": newParticipantMap // 수정된 맵으로 덮어쓰기
        });

        count++;
        if (count % batchSize === 0) {
          await batch.commit();
          batch = firestore.batch();
        }
      }

      // 남은 배치 커밋
      if (count % batchSize !== 0) {
        await batch.commit();
      }

      functions.logger.info(` - ${count}개의 챌린지에서 참여자 정보(participants, participantMap) 삭제 완료.`);
      return count;
    }).catch(err => functions.logger.error("챌린지 참여 목록 삭제 중 오류:", err)));
    // 🔥🔥🔥 [신규 추가 끝] 🔥🔥🔥

    // ▼▼▼▼▼ [친구 기능] 2. 친구 목록 및 요청에서 나를 삭제 (Collection Group) ▼▼▼▼▼

    // 2-1. 다른 사용자의 'friends' 목록에서 나를 삭제
    const friendsQuery = firestore.collectionGroup("friends").where("email", "==", email);
    contentDeletionPromises.push(friendsQuery.get().then(snapshot => {
      return deleteDocumentsInBatch(snapshot, firestore).then(count =>
        functions.logger.info(` - ${count}명의 'friends' 목록에서 본인 삭제 완료.`)
      );
    }).catch(err => functions.logger.error("친구 목록(CollectionGroup) 삭제 중 오류:", err)));

    // 2-2. 다른 사용자의 'friendRequests' 목록에서 내가 보낸 요청 삭제
    const requestsQuery = firestore.collectionGroup("friendRequests").where("senderEmail", "==", email);
    contentDeletionPromises.push(requestsQuery.get().then(snapshot => {
      return deleteDocumentsInBatch(snapshot, firestore).then(count =>
        functions.logger.info(` - ${count}개의 'friendRequests' (보낸 요청) 삭제 완료.`)
      );
    }).catch(err => functions.logger.error("친구 요청(CollectionGroup) 삭제 중 오류:", err)));

    // ▲▲▲▲▲ [친구 기능] 2. 친구 목록 및 요청에서 나를 삭제 (Collection Group) ▲▲▲▲▲


    // ▼▼▼▼▼ [ ✨✨✨ 핵심 수정 (채팅방 삭제 로직 추가) ✨✨✨ ] ▼▼▼▼▼
    // 3. 이 사용자와 연결된 모든 채팅방 및 메시지 삭제 (0번에서 조회한 friendEmails 사용)
    contentDeletionPromises.push((async () => {
      if (friendEmails.length === 0) {
        functions.logger.info(" - 삭제할 채팅방이 없습니다 (친구 없음).");
        return 0;
      }

      let deletedChatCount = 0;
      const chatDeletionPromises = [];

      for (const friendEmail of friendEmails) {
        // chatRoomId 계산
        let chatRoomId;
        // ❗️[수정] Javascript에서는 compareTo 대신 문자열 비교(>) 사용
        if (email > friendEmail) { // email이 탈퇴하는 본인 이메일
          chatRoomId = `${friendEmail}_${email}`;
        } else {
          chatRoomId = `${email}_${friendEmail}`;
        }

        const chatRoomRef = firestore.collection("userChats").doc(chatRoomId);
        const messagesPath = `userChats/${chatRoomId}/messages`;

        // 1. 하위 'messages' 컬렉션 삭제
        chatDeletionPromises.push(
          deleteCollection(firestore, messagesPath, 500)
            .then(() => {
              functions.logger.info(`   - 채팅 메시지 삭제 완료: ${messagesPath}`);
              // 2. 상위 'userChats' 문서 삭제 (메시지 삭제 후)
              return chatRoomRef.delete();
            })
            .then(() => {
              deletedChatCount++;
              functions.logger.info(`   - 채팅방 문서 삭제 완료: ${chatRoomId}`);
            })
            .catch(err => functions.logger.error(` - 채팅방(${chatRoomId}) 삭제 중 오류:`, err))
        );
      }

      await Promise.all(chatDeletionPromises);
      functions.logger.info(` - 총 ${deletedChatCount}개의 채팅방 및 하위 메시지 삭제 완료.`);
      return deletedChatCount;
    })());
    // ▲▲▲▲▲ [ ✨✨✨ 핵심 수정 (채팅방 삭제 로직 추가) ✨✨✨ ] ▲▲▲▲▲


    await Promise.all(contentDeletionPromises); // 모든 콘텐츠 삭제가 끝날 때까지 기다림
    functions.logger.info(`[성공] 사용자 생성 콘텐츠, 친구 관계, 채팅방 삭제 완료: ${email}`);


    // --- 4. Delete Firebase Auth User (Do this last) ---
    try {
      await admin.auth().deleteUser(uid);
      functions.logger.info(`[성공] Auth 계정 삭제 완료: UID=${uid}`);
    } catch (authError) {
      if (authError.code === 'auth/user-not-found') {
        functions.logger.warn(`Auth 계정(${uid})이 이미 삭제되었거나 찾을 수 없습니다.`);
      } else {
        throw authError; // 다른 Auth 오류는 에러로 처리
      }
    }

    return { success: true, message: "계정과 관련된 모든 데이터가 성공적으로 삭제되었습니다." };

  } catch (error) {
    functions.logger.error(`[오류] 계정 삭제 처리 실패 (UID=${uid}):`, error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "계정 삭제 중 서버 오류가 발생했습니다.");
  }
});

// (2)
const sendNotificationToAllUsers = onCall({ region: "asia-northeast3" }, async (request) => {
  const callerEmail = request.auth?.token?.email;
  const isAdmin = request.auth?.token?.isAdmin === true;
  // 슈퍼 관리자 또는 일반 관리자 권한 확인
  const isSuperOrGeneralAdmin = callerEmail === SUPER_ADMIN_EMAIL || request.auth?.token?.role === "general_admin";

  // 슈퍼 관리자, 일반 관리자 또는 isAdmin 클레임이 true인 경우 허용
  if (!isSuperOrGeneralAdmin && !isAdmin) {
    throw new HttpsError('permission-denied', '관리자만 이 기능을 사용할 수 있습니다.');
  }

  const { title, message } = request.data;
  if (!title || !message) {
    throw new HttpsError('invalid-argument', '함수는 "title"과 "message" 인자를 포함해야 합니다.');
  }

  try {
    await sendNotificationToUsers(title, message); // 헬퍼 함수 호출
    functions.logger.info(`전체 알림 전송 시작됨: Title="${title}", Caller=${callerEmail}`);
    return { success: true, message: '전체 사용자에게 알림 전송 및 저장이 시작되었습니다.' };
  } catch (error) {
    functions.logger.error("전체 알림 전송 함수 오류:", error);
    throw new HttpsError("internal", "알림 전송 중 오류가 발생했습니다.");
  }
});

// ▼▼▼▼▼ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 (신규 함수 1/2) ⭐️⭐️⭐️ ] ▼▼▼▼▼
/**
 * (신규) 특정 사용자 1명에게 알림을 전송합니다. (관리자용)
 */
const sendNotificationToUser = onCall({ region: "asia-northeast3" }, async (request) => {
  // 1. 권한 확인
  const callerEmail = request.auth?.token?.email;
  const callerClaims = request.auth?.token;
  if (!callerClaims) {
    throw new HttpsError("unauthenticated", "인증이 필요합니다.");
  }

  const isSuperAdmin = callerEmail === SUPER_ADMIN_EMAIL || callerClaims?.role === "super_admin";
  const isGeneralAdmin = callerClaims?.role === "general_admin";
  const canSend = callerClaims?.adminPermissions?.canSendNotifications === true;

  // 슈퍼/총괄/알림 권한이 있는 관리자만 허용
  if (!isSuperAdmin && !isGeneralAdmin && !canSend) {
    throw new HttpsError("permission-denied", "이 작업을 수행할 권한이 없습니다.");
  }

  // 2. 파라미터 확인
  const { targetEmail, title, message } = request.data;
  if (!targetEmail || !title || !message) {
    throw new HttpsError("invalid-argument", "대상 이메일, 제목, 메시지가 필요합니다.");
  }

  const timestamp = admin.firestore.Timestamp.now();

  try {
    // 3. Firestore 'notifications' 컬렉션에 저장
    const notificationRef = db
      .collection("notifications")
      .doc(targetEmail)
      .collection("items")
      .doc(); // 자동 ID

    await notificationRef.set({
      type: "admin_personal", // 👈 [신규] 관리자 개별 알림 타입
      title: title, // 관리자가 입력한 제목
      message: message, // 관리자가 입력한 내용
      timestamp: timestamp,
      isRead: false,
    });

    // 4. 대상 유저의 'fcmToken' 조회
    const targetUserDoc = await db.collection("users").doc(targetEmail).get();
    if (!targetUserDoc.exists) {
      functions.logger.warn(`[sendNotificationToUser] 대상 유저(${targetEmail})의 users 문서를 찾을 수 없어 Firestore에만 저장했습니다.`);
      return { success: true, message: "알림을 Firestore에 저장했습니다 (FCM 토큰 없음)." };
    }

    const fcmToken = targetUserDoc.data()?.fcmToken;
    if (!fcmToken) {
      functions.logger.warn(`[sendNotificationToUser] 대상 유저(${targetEmail})의 FCM 토큰이 없어 Firestore에만 저장했습니다.`);
      return { success: true, message: "알림을 Firestore에 저장했습니다 (FCM 토큰 없음)." };
    }

    // 5. FCM 푸시 알림 전송 (단일 기기)
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body: message },
      apns: { payload: { aps: { alert: { title, body: message }, sound: "default", badge: 1 } } },
      data: { screen: "UserNotificationPage" }, // 알림 클릭 시 이동할 화면
    });

    functions.logger.info(`[sendNotificationToUser] 개별 알림 전송 성공: ${callerEmail} -> ${targetEmail}, Title: "${title}"`);
    return { success: true, message: "대상 사용자에게 알림을 전송했습니다." };

  } catch (error) {
    functions.logger.error("[sendNotificationToUser] 개별 알림 전송 실패:", error);
    throw new HttpsError("internal", "알림 전송 중 오류가 발생했습니다.");
  }
});
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 (신규 함수 1/2) ⭐️⭐️⭐️ ] ▲▲▲▲▲


// (3)
const setAdminRole = onCall({ region: "asia-northeast3" }, async (request) => {
  const callerEmail = request.auth?.token?.email;
  const callerClaims = request.auth?.token;
  // ✅ 슈퍼 관리자도 권한 부여 가능하도록 수정
  const isSuperAdmin = callerEmail === SUPER_ADMIN_EMAIL || callerClaims?.role === "super_admin";
  const isGeneralAdmin = callerClaims?.role === "general_admin";

  if (!isSuperAdmin && !isGeneralAdmin) {
    throw new HttpsError("permission-denied", "이 기능을 사용할 권한이 없습니다.");
  }

  const { email: targetEmail, role: newRole, permissions } = request.data;

  // 일반 관리자가 다른 일반 관리자 임명 시도 차단
  if (isGeneralAdmin && newRole === "general_admin") {
    throw new HttpsError("permission-denied", "총괄 관리자는 다른 총괄 관리자를 임명할 수 없습니다.");
  }
  // 슈퍼 관리자가 아닌 경우, 슈퍼 관리자 역할 부여/변경 시도 차단
  if (!isSuperAdmin && newRole === "super_admin") {
    throw new HttpsError("permission-denied", "슈퍼 관리자 역할은 슈퍼 관리자만 부여할 수 있습니다.");
  }
  // 슈퍼 관리자가 아닌 경우, 슈퍼 관리자의 역할 변경 시도 차단
  if (targetEmail === SUPER_ADMIN_EMAIL && !isSuperAdmin) {
    throw new HttpsError("permission-denied", "슈퍼 관리자의 역할은 변경할 수 없습니다.");
  }

  if (!targetEmail || !newRole) {
    throw new HttpsError("invalid-argument", "이메일과 역할 데이터는 필수입니다.");
  }

  // ✅ 'super_admin' 역할 추가
  const validRoles = ['general_admin', 'admin', 'super_admin'];
  if (!validRoles.includes(newRole)) {
    throw new HttpsError("invalid-argument", `잘못된 역할입니다. 유효한 역할: ${validRoles.join(", ")}`);
  }
  // 'admin' 역할일 때만 permissions 객체 검사
  if (newRole === 'admin' && (!permissions || typeof permissions !== 'object')) {
    throw new HttpsError("invalid-argument", "'admin' 역할에는 permissions 객체가 필요합니다.");
  }

  try {
    const user = await admin.auth().getUserByEmail(targetEmail);
    const userDocRef = admin.firestore().collection("users").doc(targetEmail);

    // 역할에 따른 클레임 설정
    let claimsToSet = { role: newRole, isAdmin: true };
    if (newRole === 'super_admin') {
      claimsToSet.isSuperAdmin = true;
    }

    // Firestore 문서 업데이트 데이터 준비
    let firestoreUpdateData = { role: newRole };
    if (newRole === 'admin') {
      firestoreUpdateData.adminPermissions = permissions;
    } else { // general_admin 또는 super_admin인 경우 permissions 필드 삭제
      firestoreUpdateData.adminPermissions = admin.firestore.FieldValue.delete();
    }

    // Firestore 문서 업데이트 및 커스텀 클레임 설정
    await userDocRef.set(firestoreUpdateData, { merge: true });
    await admin.auth().setCustomUserClaims(user.uid, claimsToSet);

    functions.logger.info(`관리자 역할 부여 성공: Target=${targetEmail}, Role=${newRole}, Caller=${callerEmail}`);
    return { success: true, message: `${targetEmail} 님을 ${newRole} 역할로 설정했습니다.` };

  } catch (error) {
    functions.logger.error("관리자 역할 부여 오류:", error, { targetEmail, newRole, callerEmail });
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError("not-found", "해당 이메일의 사용자를 찾을 수 없습니다.");
    }
    throw new HttpsError("internal", `관리자 역할 부여 중 오류가 발생했습니다: ${error.message}`);
  }
});

// (4)
const removeAdminRole = onCall({ region: "asia-northeast3" }, async (request) => {
  const callerEmail = request.auth?.token?.email;
  const callerClaims = request.auth?.token;
  // ✅ 슈퍼 관리자도 권한 해제 가능하도록 수정
  const isSuperAdmin = callerEmail === SUPER_ADMIN_EMAIL || callerClaims?.role === "super_admin";
  const isGeneralAdmin = callerClaims?.role === "general_admin";

  if (!isSuperAdmin && !isGeneralAdmin) {
    throw new HttpsError("permission-denied", "이 기능을 사용할 권한이 없습니다.");
  }

  const { email: targetEmail } = request.data;
  if (!targetEmail) {
    throw new HttpsError("invalid-argument", "이메일이 제공되지 않았습니다.");
  }
  // 슈퍼 관리자의 역할 해제 시도 차단
  if (targetEmail === SUPER_ADMIN_EMAIL) {
    throw new HttpsError("permission-denied", "슈퍼 관리자의 역할은 해제할 수 없습니다.");
  }

  try {
    const targetUser = await admin.auth().getUserByEmail(targetEmail);
    const targetUserDocRef = admin.firestore().collection("users").doc(targetEmail);
    const targetUserDoc = await targetUserDocRef.get();

    if (!targetUserDoc.exists) {
      // Firestore 문서가 없어도 Auth 클레임은 제거 시도
      functions.logger.warn(`관리자 해제 대상 Firestore 문서 없음: ${targetEmail}`);
      // throw new HttpsError("not-found", "해당 사용자의 Firestore 문서를 찾을 수 없습니다.");
    }

    const targetUserData = targetUserDoc.data();

    // 권한 확인: 일반 관리자는 자신보다 높거나 같은 등급(다른 일반 관리자, 슈퍼 관리자) 해제 불가
    if (isGeneralAdmin && !isSuperAdmin) { // 호출자가 일반 관리자이고 슈퍼 관리자가 아닐 때
      // 대상이 슈퍼 관리자 또는 일반 관리자인 경우 차단
      if (targetUserData?.role === "super_admin" || targetUserData?.role === "general_admin") {
        throw new HttpsError("permission-denied", "총괄 관리자는 다른 총괄 관리자나 슈퍼 관리자를 해제할 수 없습니다.");
      }
    }

    // Firestore 문서 업데이트 (존재할 경우)
    if (targetUserDoc.exists) {
      await targetUserDocRef.update({
        role: "user", // 역할을 'user'로 변경
        adminPermissions: admin.firestore.FieldValue.delete(), // 권한 필드 삭제
      });
    }

    // Auth 커스텀 클레임 제거 (역할 관련 클레임 null로 설정)
    await admin.auth().setCustomUserClaims(targetUser.uid, {
      role: null,
      isAdmin: null,
      isSuperAdmin: null // 슈퍼 관리자 클레임도 확실히 제거
    });

    functions.logger.info(`관리자 역할 해제 성공: Target=${targetEmail}, Caller=${callerEmail}`);
    return { success: true, message: `${targetEmail} 님을 일반 사용자로 변경했습니다.` };

  } catch (error) {
    functions.logger.error("관리자 해제 오류:", error, { targetEmail, callerEmail });
    if (error.code === 'auth/user-not-found') {
      // Auth 사용자를 찾을 수 없으면 이미 삭제된 것으로 간주하고 성공 처리 가능 (선택적)
      functions.logger.warn(`관리자 해제 대상 Auth 사용자 없음: ${targetEmail}`);
      return { success: true, message: `${targetEmail} 님의 Auth 계정을 찾을 수 없지만, Firestore 정보는 업데이트 시도했습니다.` };
      // throw new HttpsError("not-found", "해당 이메일의 사용자를 찾을 수 없습니다.");
    }
    // 이미 HttpsError인 경우 그대로 throw
    if (error instanceof HttpsError) { throw error; }
    // 그 외 오류는 internal 에러로 변환
    throw new HttpsError("internal", `관리자 해제 중 오류가 발생했습니다: ${error.message}`);
  }
});

// (5)
const setSuperAdminRole = onCall({ region: "asia-northeast3" }, async (request) => {
  const userEmail = request.auth?.token?.email;
  // ✅ 함수 호출자의 역할도 확인 (슈퍼 관리자만 실행 가능)
  const callerClaims = request.auth?.token;
  const isSuperAdmin = userEmail === SUPER_ADMIN_EMAIL || callerClaims?.role === "super_admin";

  if (!isSuperAdmin) {
    throw new HttpsError('permission-denied', '이 기능은 슈퍼 관리자만 사용할 수 있습니다.');
  }

  // 대상 이메일 확인 (자기 자신에게만 부여 가능하도록 제한 해제 - 필요시 다시 추가)
  // if (userEmail !== SUPER_ADMIN_EMAIL) {
  //   throw new HttpsError('invalid-argument', '슈퍼 관리자 역할은 지정된 이메일 계정에만 부여할 수 있습니다.');
  // }

  try {
    // 지정된 슈퍼 관리자 이메일로 사용자 조회
    const user = await admin.auth().getUserByEmail(SUPER_ADMIN_EMAIL);

    // 커스텀 클레임 설정
    await admin.auth().setCustomUserClaims(user.uid, {
      isSuperAdmin: true,
      isAdmin: true, // 관리자 권한도 부여
      role: 'super_admin'
    });

    // Firestore 문서 업데이트 (역할 정보 저장)
    await admin.firestore().collection("users").doc(SUPER_ADMIN_EMAIL).set({
      role: "super_admin"
    }, { merge: true }); // 기존 데이터 유지하면서 역할만 업데이트

    functions.logger.info(`슈퍼 관리자 역할 부여 성공: Target=${SUPER_ADMIN_EMAIL}, Caller=${userEmail}`);
    return { success: true, message: "슈퍼 관리자 권한이 성공적으로 부여되었습니다." };

  } catch (error) {
    functions.logger.error("슈퍼 관리자 권한 부여 오류:", error, { callerEmail: userEmail });
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError("not-found", "슈퍼 관리자 이메일에 해당하는 사용자를 찾을 수 없습니다.");
    }
    throw new HttpsError("internal", "권한 부여 중 서버에서 오류가 발생했습니다.");
  }
});

// (6)
const clearAdminChat = onCall({ region: "us-central1", timeoutSeconds: 540, memory: "512MiB" }, async (request) => { // 메모리/타임아웃 설정
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "인증이 필요합니다.");
  }
  const claims = request.auth.token;
  // ✅ 슈퍼 관리자 또는 일반 관리자 권한 확인
  const isSuperAdmin = claims.email === SUPER_ADMIN_EMAIL || claims.role === "super_admin";
  const isGeneralAdmin = claims.role === "general_admin";

  if (!isSuperAdmin && !isGeneralAdmin) {
    throw new HttpsError("permission-denied", "이 작업을 수행할 권한이 없습니다.");
  }

  const firestore = admin.firestore();
  functions.logger.info(`[시작] 관리자 채팅 삭제 요청: Caller=${claims.email}`);

  try {
    const collectionPath = "adminChat";
    // deleteCollection 헬퍼 함수 사용
    await deleteCollection(firestore, collectionPath, 500);

    functions.logger.info(`[성공] 관리자 채팅 메시지를 모두 삭제했습니다.`);
    return { success: true, message: "채팅 기록이 모두 삭제되었습니다." };

  } catch (error) {
    functions.logger.error(`[오류] 관리자 채팅 삭제 실패:`, error);
    throw new HttpsError("internal", "채팅 기록 삭제 중 서버 오류가 발생했습니다.");
  }
});

// (7)
const designateAsMainAnnouncement = onCall({ region: "asia-northeast3" }, async (request) => {
  const claims = request.auth?.token;
  // ✅ isAdmin 클레임 존재 여부 확인
  if (!claims || !claims.isAdmin) {
    throw new HttpsError('permission-denied', '관리자만 이 기능을 사용할 수 있습니다.');
  }

  const { title, message } = request.data;
  if (!title || !message || typeof title !== 'string' || typeof message !== 'string' || title.trim() === '' || message.trim() === '') {
    throw new HttpsError('invalid-argument', '공지 제목과 내용은 비어 있을 수 없습니다.');
  }

  try {
    const announcementRef = admin.firestore().collection('mainAnnouncements').doc(); // 자동 ID 생성
    await announcementRef.set({
      title: title.trim(), // 앞뒤 공백 제거
      message: message.trim(), // 앞뒤 공백 제거
      timestamp: admin.firestore.FieldValue.serverTimestamp(), // 서버 시간 기록
      creator: claims.email, // 생성자 이메일 기록
    });

    functions.logger.info(`메인 공지 등록 성공: ID=${announcementRef.id}, Title="${title.trim()}", Caller=${claims.email}`);
    return { success: true, message: "메인 공지사항으로 등록되었습니다.", announcementId: announcementRef.id };

  } catch (error) {
    functions.logger.error("메인 공지 지정 오류:", error, { title, message, callerEmail: claims.email });
    throw new HttpsError("internal", "공지사항 등록 중 오류가 발생했습니다.");
  }
});

// (8)
const removeMainAnnouncement = onCall({ region: "asia-northeast3" }, async (request) => {
  const claims = request.auth?.token;
  // ✅ isAdmin 클레임 존재 여부 확인
  if (!claims || !claims.isAdmin) {
    throw new HttpsError('permission-denied', '관리자만 이 기능을 사용할 수 있습니다.');
  }

  const { announcementId } = request.data;
  if (!announcementId || typeof announcementId !== 'string' || announcementId.trim() === '') {
    throw new HttpsError('invalid-argument', '유효한 공지 ID가 필요합니다.');
  }

  try {
    const docRef = admin.firestore().collection('mainAnnouncements').doc(announcementId.trim());
    const doc = await docRef.get();

    // 문서가 존재하는지 확인 후 삭제
    if (doc.exists) {
      await docRef.delete();
      functions.logger.info(`메인 공지 삭제 성공: ID=${announcementId.trim()}, Caller=${claims.email}`);
      return { success: true, message: "메인 공지사항에서 삭제되었습니다." };
    } else {
      // 문서가 없으면 이미 삭제되었거나 잘못된 ID
      functions.logger.warn(`삭제할 메인 공지 없음: ID=${announcementId.trim()}, Caller=${claims.email}`);
      return { success: true, message: "해당 공지사항이 이미 삭제되었거나 존재하지 않습니다." };
    }
  } catch (error) {
    functions.logger.error("메인 공지 삭제 오류:", error, { announcementId, callerEmail: claims.email });
    // Firestore 오류 코드 5 (NOT_FOUND)는 이미 위에서 처리했으므로, 그 외 오류만 internal 에러로 처리
    throw new HttpsError("internal", "공지사항 삭제 중 오류가 발생했습니다.");
  }
});

// (9)
const sendFriendRequest = onCall({ region: "asia-northeast3" }, async (request) => { // ⭐️ [수정] enforceAppCheck 제거됨
  // 1. 인증된 사용자인지 확인
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "로그인이 필요합니다."
    );
  }

  const myEmail = request.auth.token.email;
  const recipientEmail = request.data.recipientEmail;

  if (!recipientEmail) {
    throw new HttpsError(
      "invalid-argument",
      "상대방 이메일이 필요합니다."
    );
  }

  if (myEmail === recipientEmail) {
    throw new HttpsError(
      "invalid-argument",
      "자신에게 친구 요청을 보낼 수 없습니다."
    );
  }

  // ▼▼▼▼▼ [ ✨✨✨ 수정: 친구 수 제한 (30명) 로직 추가 ✨✨✨ ] ▼▼▼▼▼
  // 관리자 여부 확인 (슈퍼 관리자 또는 일반 관리자)
  const isAdmin = request.auth.token.email === SUPER_ADMIN_EMAIL ||
                  request.auth.token.role === "super_admin" ||
                  request.auth.token.role === "general_admin";

  if (!isAdmin) {
    // 내 친구 목록 수 조회 (count() 집계 쿼리 사용)
    const friendsSnapshot = await db.collection("users").doc(myEmail).collection("friends").count().get();
    const friendCount = friendsSnapshot.data().count;

    if (friendCount >= 30) {
      throw new HttpsError(
        "failed-precondition",
        "친구 정원(30명)을 초과하여 더 이상 요청을 보낼 수 없습니다."
      );
    }
  }
  // ▲▲▲▲▲ [ ✨✨✨ 수정: 친구 수 제한 (30명) 로직 추가 ✨✨✨ ] ▲▲▲▲▲

  // 2. 내 닉네임 가져오기
  const myProfileSnap = await db.collection("users").doc(myEmail).get();
  if (!myProfileSnap.exists) {
    throw new HttpsError("not-found", "내 프로필이 없습니다.");
  }
  const myNickname = myProfileSnap.data().nickname || "이름없음";
  const myProfileImageUrl = myProfileSnap.data().profileImageUrl || null; // 프로필 이미지 URL 추가

  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  // 3. 상대방의 'friendRequests' 컬렉션에 내 정보로 문서 생성
  const requestRef = db
    .collection("users")
    .doc(recipientEmail)
    .collection("friendRequests")
    .doc(myEmail); // 요청 보낸 사람(나)의 이메일을 ID로 사용

  await requestRef.set({
    senderEmail: myEmail,
    senderNickname: myNickname,
    senderProfileImageUrl: myProfileImageUrl, // 프로필 이미지 URL 저장
    status: "pending", // 'pending', 'accepted', 'rejected'
    timestamp: timestamp,
  });

  // 4. 상대방에게 알림 보내기
  const notificationMessage = `${myNickname} 님이 친구 요청을 보냈습니다.`;
  await db
    .collection("notifications")
    .doc(recipientEmail)
    .collection("items")
    .add({
      type: "friend_request", // ✅ 새로운 알림 타입
      title: "새로운 친구 요청",
      message: notificationMessage,
      senderEmail: myEmail,
      isRead: false,
      timestamp: timestamp,
    });

  functions.logger.info(`친구 요청 성공: ${myEmail} -> ${recipientEmail}`);
  return { success: true, message: "친구 요청을 보냈습니다." };
});

// (10)
const acceptFriendRequest = onCall({ region: "asia-northeast3" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "로그인이 필요합니다."
    );
  }

  const myEmail = request.auth.token.email;
  const senderEmail = request.data.senderEmail; // 요청을 보낸 사람 이메일

  if (!senderEmail) {
    throw new HttpsError(
      "invalid-argument",
      "요청자 이메일이 필요합니다."
    );
  }

  // ▼▼▼▼▼ [ ✨✨✨ 수정: 친구 수 제한 (30명) 로직 추가 ✨✨✨ ] ▼▼▼▼▼
  // 관리자 여부 확인 (슈퍼 관리자 또는 일반 관리자)
  const isAdmin = request.auth.token.email === SUPER_ADMIN_EMAIL ||
                  request.auth.token.role === "super_admin" ||
                  request.auth.token.role === "general_admin";

  if (!isAdmin) {
    // 내 친구 목록 수 조회 (count() 집계 쿼리 사용)
    const friendsSnapshot = await db.collection("users").doc(myEmail).collection("friends").count().get();
    const friendCount = friendsSnapshot.data().count;

    if (friendCount >= 30) {
      throw new HttpsError(
        "failed-precondition",
        "친구 정원(30명)이 꽉 차서 친구 요청을 수락할 수 없습니다."
      );
    }
  }
  // ▲▲▲▲▲ [ ✨✨✨ 수정: 친구 수 제한 (30명) 로직 추가 ✨✨✨ ] ▲▲▲▲▲

  // 1. 내 닉네임 및 상대방 닉네임/프로필 이미지 가져오기
  const myProfileSnap = await db.collection("users").doc(myEmail).get();
  const senderProfileSnap = await db.collection("users").doc(senderEmail).get();

  if (!myProfileSnap.exists || !senderProfileSnap.exists) {
    throw new HttpsError(
      "not-found",
      "사용자 프로필을 찾을 수 없습니다."
    );
  }

  const myNickname = myProfileSnap.data().nickname || "이름없음";
  const myProfileImageUrl = myProfileSnap.data().profileImageUrl || null;

  const senderNickname = senderProfileSnap.data().nickname || "이름없음";
  const senderProfileImageUrl = senderProfileSnap.data().profileImageUrl || null;

  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  // 2. Batch Write 시작 (원자성 보장)
  const batch = db.batch();

  // 2-1. 내 친구 목록에 상대방 추가
  const myFriendRef = db
    .collection("users")
    .doc(myEmail)
    .collection("friends")
    .doc(senderEmail);
  batch.set(myFriendRef, {
    email: senderEmail,
    nickname: senderNickname,
    profileImageUrl: senderProfileImageUrl, // 상대방 프로필 이미지 저장
    addedAt: timestamp,
  });

  // 2-2. 상대방 친구 목록에 나 추가
  const senderFriendRef = db
    .collection("users")
    .doc(senderEmail)
    .collection("friends")
    .doc(myEmail);
  batch.set(senderFriendRef, {
    email: myEmail,
    nickname: myNickname,
    profileImageUrl: myProfileImageUrl, // 내 프로필 이미지 저장
    addedAt: timestamp,
  });

  // 2-3. 내 'friendRequests' 목록에서 해당 요청 삭제 (수락했으므로)
  const requestRef = db
    .collection("users")
    .doc(myEmail)
    .collection("friendRequests")
    .doc(senderEmail);
  batch.delete(requestRef);

  // 3. Batch Write 실행
  await batch.commit();

  // 4. (선택) 상대방에게 '수락됨' 알림 전송
  await db
    .collection("notifications")
    .doc(senderEmail)
    .collection("items")
    .add({
      type: "friend_accepted", // (선택적) 수락 알림 타입
      title: "친구 요청 수락",
      message: `${myNickname} 님이 친구 요청을 수락했습니다.`,
      isRead: false,
      timestamp: timestamp,
    });

  functions.logger.info(`친구 수락 성공: ${myEmail} <-> ${senderEmail}`);
  return { success: true, message: "친구 요청을 수락했습니다." };
});

// (11)
const rejectOrRemoveFriend = onCall({ region: "asia-northeast3", timeoutSeconds: 540 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "로그인이 필요합니다."
    );
  }

  const myEmail = request.auth.token.email;
  const friendEmail = request.data.friendEmail; // 대상 이메일

  if (!friendEmail) {
    throw new HttpsError(
      "invalid-argument",
      "대상 이메일이 필요합니다."
    );
  }

  // Batch Write 시작 (친구 관계만)
  const batch = db.batch();

  // 1. 내 친구 목록에서 상대방 삭제
  const myFriendRef = db
    .collection("users")
    .doc(myEmail)
    .collection("friends")
    .doc(friendEmail);
  batch.delete(myFriendRef);

  // 2. 상대방 친구 목록에서 나 삭제
  const friendFriendRef = db
    .collection("users")
    .doc(friendEmail)
    .collection("friends")
    .doc(myEmail);
  batch.delete(friendFriendRef);

  // 3. 내가 받은 요청(pending)이 있었다면 삭제 (거절)
  const receivedRequestRef = db
    .collection("users")
    .doc(myEmail)
    .collection("friendRequests")
    .doc(friendEmail);
  batch.delete(receivedRequestRef);

  // 4. 내가 보낸 요청(pending)이 있었다면 삭제 (요청 취소)
  const sentRequestRef = db
    .collection("users")
    .doc(friendEmail)
    .collection("friendRequests")
    .doc(myEmail);
  batch.delete(sentRequestRef);

  // ❗️[수정]
  // 5. 친구/요청 삭제 배치를 먼저 커밋합니다.
  try {
    await batch.commit();
    functions.logger.info(`친구 관계/요청 삭제 완료: ${myEmail} - ${friendEmail}`);
  } catch (error) {
    functions.logger.error(`친구 관계 삭제 배치 실패:`, error);
    throw new HttpsError("internal", "친구 관계 삭제 중 오류가 발생했습니다.");
  }


  // ▼▼▼▼▼ [ ✨ 채팅방 완전 삭제 로직 (수정됨) ✨ ] ▼▼▼▼▼
  // 6. userChats 문서 ID 계산
  let chatRoomId;
  if (myEmail > friendEmail) {
    chatRoomId = `${friendEmail}_${myEmail}`;
  } else {
    chatRoomId = `${myEmail}_${friendEmail}`;
  }

  const chatRoomRef = db.collection("userChats").doc(chatRoomId);
  const messagesPath = `userChats/${chatRoomId}/messages`;

  // ❗️[수정]
  // 7. 하위 'messages' 컬렉션을 재귀적으로 삭제합니다. (deleteCollection 헬퍼 사용)
  // 8. 하위 컬렉션 삭제 후, 상위 채팅방 문서를 삭제합니다.
  try {
    await deleteCollection(db, messagesPath, 500);
    functions.logger.info(`   - 채팅 메시지 삭제 완료: ${messagesPath}`);

    await chatRoomRef.delete();
    functions.logger.info(`   - 채팅방 문서 삭제 완료: ${chatRoomId}`);
  } catch (error) {
    // 이 단계에서 오류가 발생해도(예: 채팅방이 원래 없었음),
    // 친구 삭제는 이미 완료되었으므로 오류를 로깅만 하고 무시합니다.
    functions.logger.warn(`채팅방(${chatRoomId}) 삭제 중 경고(무시됨):`, error.message);
  }
  // ▲▲▲▲▲ [ ✨ 채팅방 완전 삭제 로직 (수정됨) ✨ ] ▲▲▲▲▲


  functions.logger.info(`친구 삭제/거절 및 채팅방 완전 정리 성공: ${myEmail} - ${friendEmail}`);
  return { success: true, message: "작업을 완료했습니다." };
});

// (12)
const clearStaleAdminSessions = onCall({ region: "asia-northeast3" }, async (request) => {
  const callerEmail = request.auth?.token?.email;
  const callerClaims = request.auth?.token;
  const isSuperAdmin = callerEmail === SUPER_ADMIN_EMAIL || callerClaims?.role === "super_admin";
  const isGeneralAdmin = callerClaims?.role === "general_admin";

  // 슈퍼/총괄 관리자만 실행 가능
  if (!isSuperAdmin && !isGeneralAdmin) {
    throw new HttpsError("permission-denied", "이 작업을 수행할 권한이 없습니다.");
  }

  functions.logger.info(`[시작] 관리자 세션 정리 요청: Caller=${callerEmail}`);

  const adminStatusRef = rtdb.ref("adminStatus");
  const now = Date.now();
  // 1시간(3600 * 1000ms) 이상 갱신되지 않은 세션을 'stale'로 간주
  const staleThreshold = now - (3600 * 1000);

  try {
    const snapshot = await adminStatusRef.once("value");
    if (!snapshot.exists()) {
      functions.logger.info("정리할 관리자 세션이 없습니다 (adminStatus 노드 없음).");
      return { success: true, message: "정리할 세션이 없습니다." };
    }

    const sessions = snapshot.val();
    const updates = {}; // RTDB 멀티-패스 업데이트용 객체
    let staleCount = 0;

    for (const key in sessions) {
      const session = sessions[key];

      // 세션 데이터가 객체가 아니거나, lastSeen이 없거나, isOnline이 true가 아닌 경우 무시
      if (typeof session !== 'object' || session === null || !session.lastSeen || session.isOnline !== true) {
        continue;
      }

      // lastSeen이 staleThreshold보다 오래된 경우
      if (session.lastSeen < staleThreshold) {
        functions.logger.info(` - Stale 세션 발견: Key=${key}, Nickname=${session.nickname}, LastSeen=${new Date(session.lastSeen).toISOString()}`);
        updates[key] = null; // 해당 키를 null로 설정하여 삭제
        staleCount++;
      }
    }

    if (staleCount > 0) {
      await adminStatusRef.update(updates); // 멀티-패스 업데이트로 stale 세션 일괄 삭제
      functions.logger.info(`[성공] ${staleCount}개의 오래된 관리자 세션을 정리했습니다.`);
      return { success: true, message: `${staleCount}개의 오래된 세션을 정리했습니다.` };
    } else {
      functions.logger.info("[성공] 활성 중인 세션 중 오래된 세션이 없습니다.");
      return { success: true, message: "모든 활성 세션이 최신입니다." };
    }

  } catch (error) {
    functions.logger.error(`[오류] 관리자 세션 정리 실패:`, error);
    throw new HttpsError("internal", "세션 정리 중 서버 오류가 발생했습니다.");
  }
});

// (13)
const searchUsersWithStatus = onCall({ region: "asia-northeast3", memory: "512MiB" }, async (request) => {
  // 1. 인증된 사용자인지 확인
  if (!request.auth || !request.auth.token.email) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }

  const searchTerm = request.data.nickname;
  const myEmail = request.auth.token.email; // 내 이메일

  if (!searchTerm || typeof searchTerm !== 'string' || searchTerm.trim().length < 1) { // 닉네임이 1글자일 수도 있으니 1글자 이상
    throw new HttpsError("invalid-argument", "검색할 닉네임을 1글자 이상 입력해야 합니다.");
  }

  const trimmedSearchTerm = searchTerm.trim();

  // 클라이언트에서 displayName이 최신이 아닐 수 있으니, users 문서에서 내 닉네임을 가져와서 비교합니다.
  const myUserDoc = await db.collection("users").doc(myEmail).get();
  const myNickname = myUserDoc.data()?.nickname;

  if (trimmedSearchTerm === myNickname) {
     // 참고: 클라이언트에서도 이미 체크하고 있지만, 서버에서도 한 번 더 방어
    functions.logger.info(`검색 차단: 자기 자신 검색 시도, Caller=${myEmail}`);
    return { success: true, users: [] }; // 오류 대신 빈 배열 반환
  }


  try {
    // 2. 서버(admin) 권한으로 닉네임 쿼리 실행 (isEqualTo)
    // (기존 Dart 코드와 동일하게 'isEqualTo' 사용)
    const querySnapshot = await db.collection("users")
        .where("nickname", "==", trimmedSearchTerm)
        .limit(20) // 👈 한 번에 20명만 반환 (악의적 동명 닉네임 검색 방지)
        .get();

    if (querySnapshot.empty) {
      functions.logger.info(`검색 결과 없음: Term="${trimmedSearchTerm}", Caller=${myEmail}`);
      return { success: true, users: [] };
    }

    const resultsWithStatus = [];

    // 3. 검색 결과를 순회하며 '친구 상태'를 병렬로 확인 (N+1 문제 해결)
    for (const doc of querySnapshot.docs) {
      const foundUserEmail = doc.id;

      // 3-1. 검색 결과가 '나'인 경우 제외 (쿼리에서 이미 제외했지만 이중 체크)
      if (foundUserEmail === myEmail) {
        continue;
      }

      const userData = doc.data();

      // 3-2. 친구 상태 확인 (3가지 쿼리를 동시에 실행)
      const [friendSnap, sentSnap, receivedSnap] = await Promise.all([
        db.collection("users").doc(myEmail).collection("friends").doc(foundUserEmail).get(),
        db.collection("users").doc(foundUserEmail).collection("friendRequests").doc(myEmail).get(),
        db.collection("users").doc(myEmail).collection("friendRequests").doc(foundUserEmail).get()
      ]);

      let status = 'none';
      if (friendSnap.exists) {
        status = 'friends';
      } else if (sentSnap.exists && sentSnap.data()?.status === 'pending') {
        status = 'pending_sent';
      } else if (receivedSnap.exists && receivedSnap.data()?.status === 'pending') {
        status = 'pending_received';
      }

      // 3-3. 최종 결과 배열에 추가 (민감 정보 제외)
      resultsWithStatus.push({
        email: foundUserEmail,
        nickname: userData.nickname || "알 수 없음",
        profileImageUrl: userData.profileImageUrl || null,
        friendshipStatus: status // 👈 서버가 모든 상태를 결정해서 전달
      });
    }

    functions.logger.info(`닉네임 검색 성공: Term="${trimmedSearchTerm}", Results=${resultsWithStatus.length}, Caller=${myEmail}`);
    return { success: true, users: resultsWithStatus };

  } catch (error) {
    functions.logger.error("닉네임 검색 오류:", error, { searchTerm, callerEmail: myEmail });
    throw new HttpsError("internal", "검색 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.");
  }
});

// (14)
const deleteEventChallenge = onCall({ region: "asia-northeast3", timeoutSeconds: 540, memory: "512MiB" }, async (request) => {
  // 1. 관리자 권한 확인
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "인증이 필요합니다.");
  }
  const claims = request.auth.token;
  // (isAdmin() 헬퍼 함수가 없으므로 클레임 직접 확인)
  const isAdmin = claims.isAdmin === true;
  if (!isAdmin) {
    throw new HttpsError("permission-denied", "이 작업을 수행할 관리자 권한이 없습니다.");
  }

  // 2. 파라미터 확인
  const { eventId } = request.data;
  if (!eventId || typeof eventId !== 'string' || eventId.trim() === '') {
    throw new HttpsError("invalid-argument", "유효한 'eventId'가 필요합니다.");
  }

  functions.logger.info(`[시작] 이벤트 챌린지 삭제 요청: ID=${eventId}, Caller=${claims.email}`);

  const firestore = admin.firestore();
  const eventRef = firestore.collection("eventChallenges").doc(eventId);
  const participantsPath = `eventChallenges/${eventId}/participants`;

  try {
    // 3. 하위 컬렉션 ('participants') 삭제 (helpers.js의 deleteCollection 사용)
    functions.logger.info(` - [${eventId}] 하위 participants 컬렉션 삭제 시작...`);
    await deleteCollection(firestore, participantsPath, 500);
    functions.logger.info(` - [${eventId}] 하위 participants 컬렉션 삭제 완료.`);

    // 4. 상위 문서 ('eventChallenges') 삭제
    await eventRef.delete();
    functions.logger.info(`[성공] 이벤트 챌린지 문서 삭제 완료: ID=${eventId}`);

    return { success: true, message: "이벤트 챌린지와 모든 참여자 데이터가 삭제되었습니다." };

  } catch (error) {
    functions.logger.error(`[오류] 이벤트 챌린지(${eventId}) 삭제 실패:`, error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "이벤트 삭제 중 서버 오류가 발생했습니다.");
  }
});


// ▼▼▼▼▼ [ ⭐️⭐️⭐️ (15) 닉네임 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
/**
 * (15) [신규] 친구에게 러닝 대결을 신청합니다. (실시간)
 * (호출: FriendBattleListScreen)
 */
const sendFriendBattleRequest = onCall({ region: "asia-northeast3" }, async (request) => {
  // 1. 인증 확인
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const myEmail = request.auth.token.email;

  const { opponentEmail, targetDistanceKm } = request.data;
  if (!opponentEmail || !targetDistanceKm) {
    throw new HttpsError("invalid-argument", "상대방 이메일과 목표 거리가 필요합니다.");
  }

  if (myEmail === opponentEmail) {
    throw new HttpsError("invalid-argument", "자신에게 대결을 신청할 수 없습니다.");
  }

  // 2. 상대방 정보 조회 (프로필 사진 등)
  const opponentUserDoc = await db.collection("users").doc(opponentEmail).get();
  if (!opponentUserDoc.exists) {
    throw new HttpsError("not-found", "상대방 사용자 정보를 찾을 수 없습니다.");
  }
  const opponentData = opponentUserDoc.data();
  const opponentNickname = opponentData.nickname || "상대방";
  const opponentProfileUrl = opponentData.profileImageUrl || null;

  // ▼▼▼▼▼ [ ⭐️ 수정: FCM 푸시 알림 추가 ⭐️ ] ▼▼▼▼▼
  const opponentFcmToken = opponentData.fcmToken; // 👈 토큰 가져오기
  // ▲▲▲▲▲ [ ⭐️ 수정: FCM 푸시 알림 추가 ⭐️ ] ▲▲▲▲▲

  // 3. 내 프로필 정보 조회 (닉네임, 프로필 사진 등)
  const myUserDoc = await db.collection("users").doc(myEmail).get();
  if (!myUserDoc.exists) {
    throw new HttpsError("not-found", "내 프로필이 없습니다. (users doc)");
  }
  // ⭐️ [수정] Auth 토큰 대신 Firestore 'users' 문서에서 닉네임 조회
  const myNickname = myUserDoc.data().nickname || "알 수 없음";
  const myProfileUrl = myUserDoc.data().profileImageUrl || null;

  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  try {
    // 4. `friendBattles` 컬렉션에 새 대결 문서 생성
    const battleRef = db.collection("friendBattles").doc(); // 자동 ID
    const battleId = battleRef.id;

    await battleRef.set({
      status: "pending", // 'pending', 'accepted', 'rejected', 'running', 'finished', 'cancelled'
      challengerEmail: myEmail,
      challengerNickname: myNickname, // 👈 수정된 닉네임 사용
      challengerProfileUrl: myProfileUrl,
      challengerStatus: "ready", // 'ready', 'running', 'finished'

      opponentEmail: opponentEmail,
      opponentNickname: opponentNickname,
      opponentProfileUrl: opponentProfileUrl,
      opponentStatus: "waiting", // 'waiting', 'ready', 'running', 'finished'

      targetDistanceKm: targetDistanceKm,
      createdAt: timestamp,
      // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 핵심 수정: participants 추가 ⭐️⭐️⭐️ ] ▼▼▼▼▼
      participants: [myEmail, opponentEmail], // 👈 리스트 조회를 위해 필수
      // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 핵심 수정: participants 추가 ⭐️⭐️⭐️ ] ▲▲▲▲▲
    });

    // 5. 상대방에게 알림 전송
    await db
      .collection("notifications")
      .doc(opponentEmail)
      .collection("items")
      .add({
        type: "battle_request", // 👈 [신규] 알림 타입
        title: `${myNickname} 님이 대결을 신청했습니다!`, // 👈 수정된 닉네임 사용
        message: `[${targetDistanceKm}km] 러닝 대결을 수락하시겠습니까?`,
        battleId: battleId, // 👈 [신규] 알림 탭 시 이동할 battleId
        senderEmail: myEmail,
        isRead: false,
        timestamp: timestamp,
      });

    // ▼▼▼▼▼ [ ⭐️ 수정: FCM 푸시 알림 추가 ⭐️ ] ▼▼▼▼▼
    if (opponentFcmToken) {
        try {
            await admin.messaging().send({
                token: opponentFcmToken,
                notification: {
                    title: `${myNickname} 님이 대결을 신청했습니다!`,
                    body: `[${targetDistanceKm}km] 러닝 대결을 수락하시겠습니까?`
                },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
                data: { screen: "UserNotificationPage" } // 알림 클릭 시 이동할 화면
            });
        } catch (e) {
            functions.logger.error(`FCM 전송 실패 (${opponentEmail}):`, e);
        }
    }
    // ▲▲▲▲▲ [ ⭐️ 수정: FCM 푸시 알림 추가 ⭐️ ] ▲▲▲▲▲

    functions.logger.info(`친구 대결 신청 성공: ${myEmail} -> ${opponentEmail} (BattleID: ${battleId})`);
    return { success: true, battleId: battleId };

  } catch (error) {
    functions.logger.error("친구 대결 신청 오류:", error);
    throw new HttpsError("internal", "대결 신청 중 오류가 발생했습니다.");
  }
});
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ (15) 닉네임 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲

// (16)
const respondToFriendBattleRequest = onCall({ region: "asia-northeast3" }, async (request) => {
  // 1. 인증 확인 (응답자 = 상대방)
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const myEmail = request.auth.token.email; // 내가 상대방(opponent)

  const { battleId, response } = request.data; // response: "accepted" 또는 "rejected"
  if (!battleId || !response) {
    throw new HttpsError("invalid-argument", "Battle ID와 응답(accepted/rejected)이 필요합니다.");
  }

  const battleRef = db.collection("friendBattles").doc(battleId);

  try {
    const battleDoc = await battleRef.get();
    if (!battleDoc.exists) {
      throw new HttpsError("not-found", "해당 대결을 찾을 수 없습니다.");
    }

    const battleData = battleDoc.data();

    // 2. 내가 이 대결의 '상대방'이 맞는지 확인
    if (battleData.opponentEmail !== myEmail) {
      throw new HttpsError("permission-denied", "이 대결에 응답할 권한이 없습니다.");
    }

    // 3. 이미 'pending' 상태가 아닌지 확인
    if (battleData.status !== "pending") {
      throw new HttpsError("failed-precondition", "이미 시작되었거나 취소된 대결입니다.");
    }

    // 4. 응답에 따라 상태 업데이트
    if (response === "accepted") {
      await battleRef.update({
        status: "accepted", // 👈 'accepted' (양쪽 다 로비에 있음)
        opponentStatus: "ready", // 👈 상대방(나)도 준비 완료
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      // (TODO: 도전자에게 '수락됨' 알림을 보낼 수 있음)
      functions.logger.info(`대결 수락됨: (BattleID: ${battleId})`);
      return { success: true, message: "대결을 수락했습니다." };

    } else if (response === "rejected") {
      await battleRef.update({
        status: "rejected", // 👈 'rejected' (거절됨)
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      // (TODO: 도전자에게 '거절됨' 알림을 보낼 수 있음)
      functions.logger.info(`대결 거절됨: (BattleID: ${battleId})`);
      return { success: true, message: "대결을 거절했습니다." };

    } else {
      throw new HttpsError("invalid-argument", "유효하지 않은 응답입니다.");
    }

  } catch (error) {
    functions.logger.error(`대결 응답 오류 (BattleID: ${battleId}):`, error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "대결 응답 중 오류가 발생했습니다.");
  }
});

// (17)
const cancelFriendBattle = onCall({ region: "asia-northeast3" }, async (request) => {
  // 1. 인증 확인
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const myEmail = request.auth.token.email;

  const { battleId } = request.data;
  if (!battleId) {
    throw new HttpsError("invalid-argument", "Battle ID가 필요합니다.");
  }

  const battleRef = db.collection("friendBattles").doc(battleId);

  try {
    const battleDoc = await battleRef.get();
    if (!battleDoc.exists) {
      throw new HttpsError("not-found", "해당 대결을 찾을 수 없습니다.");
    }

    const battleData = battleDoc.data();

    // 2. 내가 이 대결의 '도전자' 또는 '상대방'이 맞는지 확인
    if (battleData.challengerEmail !== myEmail && battleData.opponentEmail !== myEmail) {
      throw new HttpsError("permission-denied", "이 대결을 취소할 권한이 없습니다.");
    }

    // 3. 'running' 또는 'finished' 상태가 아닌지 확인
    if (battleData.status === "running" || battleData.status === "finished") {
      throw new HttpsError("failed-precondition", "이미 시작된 대결은 취소할 수 없습니다.");
    }

    // 4. 'cancelled'로 상태 업데이트
    // (이미 'rejected'나 'cancelled'여도 덮어쓰기)
    await battleRef.update({
      status: "cancelled",
      cancellerEmail: myEmail, // 👈 [신규] 누가 취소했는지 기록
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`대결 취소됨: (BattleID: ${battleId})`);
    return { success: true, message: "대결을 취소했습니다." };

  } catch (error) {
    functions.logger.error(`대결 취소 오류 (BattleID: ${battleId}):`, error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "대결 취소 중 오류가 발생했습니다.");
  }
});


// ▼▼▼▼▼ [ ⭐️⭐️⭐️ (18) 닉네임 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
/**
 * (18) [신규] 친구에게 '오프라인(비동기)' 대결을 신청합니다.
 * (호출: (신규) AsyncBattleCreateScreen)
 */
const sendAsyncBattleRequest = onCall({ region: "asia-northeast3" }, async (request) => {
  // 1. 인증 확인
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const myEmail = request.auth.token.email;

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (1/3) ⭐️⭐️⭐️ ] ▼▼▼▼▼
  // const { opponentEmail, targetDistanceKm } = request.data;
  // 클라이언트가 보낸 'challengerNickname'도 받음
  const { opponentEmail, targetDistanceKm, challengerNickname } = request.data;
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (1/3) ⭐️⭐️⭐️ ] ▲▲▲▲▲

  if (!opponentEmail || !targetDistanceKm) {
    throw new HttpsError("invalid-argument", "상대방 이메일과 목표 거리가 필요합니다.");
  }

  if (myEmail === opponentEmail) {
    throw new HttpsError("invalid-argument", "자신에게 대결을 신청할 수 없습니다.");
  }

  // 2. 상대방 정보 조회
  const opponentUserDoc = await db.collection("users").doc(opponentEmail).get();
  if (!opponentUserDoc.exists) {
    throw new HttpsError("not-found", "상대방 사용자 정보를 찾을 수 없습니다.");
  }
  const opponentData = opponentUserDoc.data();
  const opponentNickname = opponentData.nickname || "상대방";
  const opponentProfileUrl = opponentData.profileImageUrl || null;

  // ▼▼▼▼▼ [ ⭐️ 수정: FCM 푸시 알림 추가 ⭐️ ] ▼▼▼▼▼
  const opponentFcmToken = opponentData.fcmToken; // 👈 토큰 가져오기
  // ▲▲▲▲▲ [ ⭐️ 수정: FCM 푸시 알림 추가 ⭐️ ] ▲▲▲▲▲

  // 3. 내 프로필 정보 조회
  const myUserDoc = await db.collection("users").doc(myEmail).get();
  if (!myUserDoc.exists) {
    throw new HttpsError("not-found", "내 프로필이 없습니다. (users doc)");
  }

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (2/3) ⭐️⭐️⭐️ ] ▼▼▼▼▼
  // ⭐️ [수정] 클라이언트가 보낸 'challengerNickname'을 우선 사용, 없으면 DB 조회, 그것도 없으면 "알 수 없음"
  const myNickname = challengerNickname || myUserDoc.data().nickname || "알 수 없음";
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (2/3) ⭐️⭐️⭐️ ] ▲▲▲▲▲

  const myProfileUrl = myUserDoc.data().profileImageUrl || null;

  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  try {
    // 4. `asyncBattles` 컬렉션에 새 대결 문서 생성 (신규 컬렉션)
    const battleRef = db.collection("asyncBattles").doc(); // 자동 ID
    const battleId = battleRef.id;

    await battleRef.set({
      status: "pending", // 'pending' (도전자 뛸 차례), 'running' (상대방 뛸 차례), 'finished', 'cancelled'
      challengerEmail: myEmail,
      challengerNickname: myNickname, // 👈 수정된 닉네임 사용
      challengerProfileUrl: myProfileUrl,
      challengerRunData: null, // 도전자가 뛰면 여기에 기록 저장

      opponentEmail: opponentEmail,
      opponentNickname: opponentNickname,
      opponentProfileUrl: opponentProfileUrl,
      opponentRunData: null, // 상대방이 뛰면 여기에 기록 저장

      targetDistanceKm: targetDistanceKm,
      createdAt: timestamp,
      // 'winnerEmail', 'loserEmail' 등은 'finished' 상태가 될 때 추가
    });

    // 5. 상대방에게 알림 전송 (신규 타입)
    await db
      .collection("notifications")
      .doc(opponentEmail)
      .collection("items")
      .add({
        type: "async_battle_request", // 👈 [신규] 알림 타입
        // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (3/3) ⭐️⭐️⭐️ ] ▼▼▼▼▼
        title: `${myNickname} 님이 오프라인 대결을 신청했습니다!`, // 👈 수정된 닉네임 사용
        // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (3/3) ⭐️⭐️⭐️ ] ▲▲▲▲▲
        message: `[${targetDistanceKm}km] 러닝 대결을 수락하시겠습니까?`,
        battleId: battleId,
        senderEmail: myEmail,
        isRead: false,
        timestamp: timestamp,
      });

    // ▼▼▼▼▼ [ ⭐️ 수정: FCM 푸시 알림 추가 ⭐️ ] ▼▼▼▼▼
    if (opponentFcmToken) {
        try {
            await admin.messaging().send({
                token: opponentFcmToken,
                notification: {
                    title: `${myNickname} 님이 오프라인 대결을 신청했습니다!`,
                    body: `[${targetDistanceKm}km] 러닝 대결을 수락하시겠습니까?`
                },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
                data: { screen: "UserNotificationPage" } // 알림 클릭 시 이동할 화면
            });
        } catch (e) {
            functions.logger.error(`FCM 전송 실패 (${opponentEmail}):`, e);
        }
    }
    // ▲▲▲▲▲ [ ⭐️ 수정: FCM 푸시 알림 추가 ⭐️ ] ▲▲▲▲▲

    functions.logger.info(`오프라인 대결 신청 성공: ${myEmail} -> ${opponentEmail} (AsyncBattleID: ${battleId})`);
    // [수정] 도전자(나)가 바로 러닝 페이지로 이동할 수 있도록 battleId를 반환
    return { success: true, battleId: battleId };

  } catch (error) {
    functions.logger.error("오프라인 대결 신청 오류:", error);
    throw new HttpsError("internal", "대결 신청 중 오류가 발생했습니다.");
  }
});
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ (18) 닉네임 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲

// ▼▼▼▼▼ [ ⭐️⭐️⭐️ (19) 닉네임 및 무승부 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
const completeAsyncBattle = onCall({ region: "asia-northeast3", memory: "512MiB" }, async (request) => {
  // 1. 인증 확인
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const myEmail = request.auth.token.email;

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (1/3) ⭐️⭐️⭐️ ] ▼▼▼▼▼
  // const myNickname = request.auth.token.name || "알 수 없음"; // 👈 (기존)
  const { battleId, runData, completerNickname } = request.data; // 👈 [수정] completerNickname 받기

  // [수정] 클라이언트가 보낸 'completerNickname'을 우선 사용
  const myNickname = completerNickname || request.auth.token.name || "알 수 없음";
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (1/3) ⭐️⭐️⭐️ ] ▲▲▲▲▲


  if (!battleId || !runData || runData.seconds === undefined) { // 👈 undefined 체크 (0초일수도 있으므로)
    throw new HttpsError("invalid-argument", "Battle ID와 러닝 기록 데이터가 필요합니다.");
  }

  const battleRef = db.collection("asyncBattles").doc(battleId);
  const now = admin.firestore.FieldValue.serverTimestamp();

  try {
    const battleDoc = await battleRef.get();
    if (!battleDoc.exists) {
      throw new HttpsError("not-found", "해당 대결을 찾을 수 없습니다.");
    }

    const battleData = battleDoc.data();

    // 2. 내가 이 대결의 참여자가 맞는지 확인
    const isChallenger = battleData.challengerEmail === myEmail;
    const isOpponent = battleData.opponentEmail === myEmail;

    if (!isChallenger && !isOpponent) {
      throw new HttpsError("permission-denied", "이 대결의 참여자가 아닙니다.");
    }
    // 3. 이미 끝난 대결인지 확인
    if (battleData.status === "finished" || battleData.status === "cancelled") {
      throw new HttpsError("failed-precondition", "이미 종료된 대결입니다.");
    }

    // 4. 내 기록을 저장할 필드 준비
    const myRunData = { ...runData, recordedAt: now };
    let updatePayload = {};
    let otherUserData = null; // 상대방의 기록 데이터 (이미 있다면)
    let notificationTitle = "";
    let notificationMessage = "";
    let otherUserEmail = ""; // 알림 보낼 상대방 이메일

    // 5. 내가 '도전자'인지 '상대방'인지에 따라 분기
    if (isChallenger) {
      // 5-A. 도전자(선공)인 경우
      if (battleData.challengerRunData != null) {
        throw new HttpsError("failed-precondition", "이미 기록을 제출했습니다.");
      }
      updatePayload = {
        challengerRunData: myRunData,
        status: "running", // 'running' = 상대방(후공)이 뛸 차례
        updatedAt: now,
      };
      otherUserData = battleData.opponentRunData; // (이 시점엔 null이어야 함)
      otherUserEmail = battleData.opponentEmail;
      // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (2/3) ⭐️⭐️⭐️ ] ▼▼▼▼▼
      notificationTitle = `${myNickname} 님이 오프라인 대결을 완료했습니다!`; // 👈 수정된 닉네임 사용
      // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 오류 수정 (2/3) ⭐️⭐️⭐️ ] ▲▲▲▲▲
      notificationMessage = `이제 ${battleData.opponentNickname} 님이 뛸 차례입니다. [${battleData.targetDistanceKm}km]`;

    } else {
      // 5-B. 상대방(후공)인 경우
      if (battleData.opponentRunData != null) {
        throw new HttpsError("failed-precondition", "이미 기록을 제출했습니다.");
      }
      if (battleData.challengerRunData == null) {
        throw new HttpsError("failed-precondition", "아직 도전자가 기록을 제출하지 않았습니다.");
      }
      updatePayload = {
        opponentRunData: myRunData,
        updatedAt: now,
      };
      otherUserData = battleData.challengerRunData; // (이 시점엔 기록이 있어야 함)
      otherUserEmail = battleData.challengerEmail;
      // (후공일 경우, 승패 판정 후 알림 내용을 덮어쓸 것임)
    }

    // 6. [중요] 상대방 기록(otherUserData)이 있는지 확인 (승패 판정)
    if (otherUserData != null) {
      // 6-A. 상대방 기록이 있다 = 내가 '후공'이다 = 승패 판정
      functions.logger.info(`[AsyncBattle] ${battleId} 대결의 후공 기록 제출. 승패 판정 시작...`);

      // ▼▼▼▼▼ [ ✨✨✨ 소수점 비교 로직 수정 ✨✨✨ ] ▼▼▼▼▼
      // 소수점(double) 비교를 위해 Number()로 확실하게 변환
      const myTime = Number(myRunData.seconds);
      const otherTime = Number(otherUserData.seconds);

      // 알림 메시지용 포맷팅 (소수점 2자리까지 표시)
      const myTimeStr = myTime.toFixed(2);
      const otherTimeStr = otherTime.toFixed(2);

      let winnerEmail, loserEmail, winnerTime, loserTime;
      let isDraw = false; // 👈 [신규] 무승부 플래그

      if (myTime < otherTime) { // 내가 이김 (시간이 더 짧음)
        winnerEmail = myEmail;
        loserEmail = otherUserEmail;
        winnerTime = myTime;
        loserTime = otherTime;
        notificationTitle = `[${battleData.targetDistanceKm}km] 대결에서 승리했습니다!`;
        notificationMessage = `${myNickname} 님이 ${otherTimeStr}초 기록의 ${battleData.challengerNickname} 님을 ${myTimeStr}초로 이겼습니다!`;

      } else if (myTime > otherTime) { // 내가 짐 (시간이 더 김)
        winnerEmail = otherUserEmail;
        loserEmail = myEmail;
        winnerTime = otherTime;
        loserTime = myTime;
        notificationTitle = `[${battleData.targetDistanceKm}km] 대결에서 패배했습니다.`;
        notificationMessage = `${battleData.challengerNickname} 님이 ${otherTimeStr}초 기록으로 ${myNickname} 님(${myTimeStr}초)을 이겼습니다.`;

      } else { // 무승부 (시간이 같음)
        isDraw = true;
        winnerEmail = null; // 무승부이므로 승자 없음
        loserEmail = null;
        winnerTime = myTime; // 기록용으로 둘 다 저장
        loserTime = otherTime;
        notificationTitle = `[${battleData.targetDistanceKm}km] 대결 결과: 무승부!`;
        notificationMessage = `두 분 모두 ${myTimeStr}초로 기록이 동일합니다. 무승부입니다!`;
      }
      // ▲▲▲▲▲ [ ✨✨✨ 소수점 비교 로직 수정 ✨✨✨ ] ▲▲▲▲▲

      // 6-B. 승패 판정 결과를 Firestore Batch에 추가
      const batch = db.batch();

      // 1. 대결 문서(asyncBattles) 업데이트
      updatePayload.status = "finished";
      updatePayload.winnerEmail = winnerEmail;
      updatePayload.loserEmail = loserEmail;
      updatePayload.winnerTime = winnerTime;
      updatePayload.loserTime = loserTime;
      updatePayload.isDraw = isDraw; // 👈 [신규] 무승부 여부 저장
      batch.update(battleRef, updatePayload);

      // 2. 승자/패자/무승부 사용자 문서 업데이트
      if (!isDraw) {
        // 승패가 갈린 경우
        const winnerRef = db.collection("users").doc(winnerEmail);
        batch.update(winnerRef, { "battleWins": admin.firestore.FieldValue.increment(1) });

        const loserRef = db.collection("users").doc(loserEmail);
        batch.update(loserRef, { "battleLosses": admin.firestore.FieldValue.increment(1) });
      } else {
        // 무승부인 경우 (선택사항: battleDraws 필드가 있다면 증가)
        const meRef = db.collection("users").doc(myEmail);
        batch.update(meRef, { "battleDraws": admin.firestore.FieldValue.increment(1) });

        const otherRef = db.collection("users").doc(otherUserEmail);
        batch.update(otherRef, { "battleDraws": admin.firestore.FieldValue.increment(1) });
      }

      // 6-C. Batch 실행
      await batch.commit();

      // 6-D. 양쪽에게 결과 알림 전송 (신규 타입)
      await db.collection("notifications").doc(myEmail).collection("items").add({
        type: "async_battle_result",
        title: notificationTitle,
        message: notificationMessage,
        battleId: battleId,
        isRead: false,
        timestamp: now,
      });
      await db.collection("notifications").doc(otherUserEmail).collection("items").add({
        type: "async_battle_result",
        title: notificationTitle,
        message: notificationMessage,
        battleId: battleId,
        isRead: false,
        timestamp: now,
      });

      functions.logger.info(`[AsyncBattle] ${battleId} 대결 종료. 승자: ${isDraw ? "무승부" : winnerEmail}`);
      return { success: true, message: isDraw ? "대결 완료! 무승부입니다." : "대결 완료! 승패가 결정되었습니다." };

    } else {
      // 7. 상대방 기록이 없다 = 내가 '선공'이다 = 단순 기록 저장
      functions.logger.info(`[AsyncBattle] ${battleId} 대결의 선공 기록 제출. 상대방 대기 중...`);
      await battleRef.update(updatePayload);

      // 7-A. 상대방에게 '이제 네 차례' 알림 전송 (신규 타입)
      await db.collection("notifications").doc(otherUserEmail).collection("items").add({
        type: "async_battle_turn", // 👈 [신규] 알림 타입
        title: notificationTitle,
        message: notificationMessage,
        battleId: battleId,
        isRead: false,
        timestamp: now,
      });

      return { success: true, message: "기록 제출 완료. 상대방의 응답을 기다립니다." };
    }

  } catch (error) {
    functions.logger.error(`오프라인 대결 완료 오류 (BattleID: ${battleId}):`, error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "대결 기록 제출 중 오류가 발생했습니다.");
  }
});
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ (19) 닉네임 및 무승부 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲

// ▼▼▼▼▼ [ ⭐️⭐️⭐️ (20) 닉네임 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
const cancelAsyncBattle = onCall({ region: "asia-northeast3" }, async (request) => {
  // 1. 인증 확인
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const myEmail = request.auth.token.email;

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 오류 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  // [수정] Firestore에서 닉네임을 조회하도록 로직 변경
  // const myNickname = request.auth.token.name || "알 수 없음"; // 👈 (기존)
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 오류 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲

  const { battleId } = request.data;
  if (!battleId) {
    throw new HttpsError("invalid-argument", "Battle ID와 필요합니다.");
  }

  const battleRef = db.collection("asyncBattles").doc(battleId);

  try {
    const battleDoc = await battleRef.get();
    if (!battleDoc.exists) {
      throw new HttpsError("not-found", "해당 대결을 찾을 수 없습니다.");
    }

    // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 오류 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
    // [신규] 내 닉네임을 DB에서 조회
    const myUserDoc = await db.collection("users").doc(myEmail).get();
    const myNickname = myUserDoc.data()?.nickname || "알 수 없음";
    // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 오류 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲

    const battleData = battleDoc.data();

    // 2. 내가 이 대결의 '도전자' 또는 '상대방'이 맞는지 확인
    const isChallenger = battleData.challengerEmail === myEmail;
    const isOpponent = battleData.opponentEmail === myEmail;

    if (!isChallenger && !isOpponent) {
      throw new HttpsError("permission-denied", "이 대결을 취소할 권한이 없습니다.");
    }

    // 3. 'finished' 상태가 아닌지 확인
    if (battleData.status === "finished") {
      throw new HttpsError("failed-precondition", "이미 완료된 대결은 취소할 수 없습니다.");
    }

    // 4. 'cancelled'로 상태 업데이트
    await battleRef.update({
      status: "cancelled",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. 상대방에게 '취소됨' 알림 전송
    const otherUserEmail = isChallenger ? battleData.opponentEmail : battleData.challengerEmail;
    await db.collection("notifications").doc(otherUserEmail).collection("items").add({
      type: "async_battle_result", // (결과 알림 타입 재사용)
      title: "오프라인 대결 취소",
      // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 오류 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
      message: `${myNickname} 님이 [${battleData.targetDistanceKm}km] 대결을 취소했습니다.`, // 👈 수정된 닉네임 사용
      // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 오류 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲
      battleId: battleId,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`오프라인 대결 취소됨: (BattleID: ${battleId}) by ${myEmail}`);
    return { success: true, message: "대결을 취소했습니다." };

  } catch (error) {
    functions.logger.error(`오프라인 대결 취소 오류 (BattleID: ${battleId}):`, error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "대결 취소 중 오류가 발생했습니다.");
  }
});
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ (20) 닉네임 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲


// --- 4. 정의한 모든 Callable 함수들을 내보내기(export) ---
// ▼▼▼▼▼ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 (신규 함수 2/2) ⭐️⭐️⭐️ ] ▼▼▼▼▼
module.exports = {
  deleteUserAccount,
  sendNotificationToAllUsers,
  sendNotificationToUser, // 👈 [신규 추가]
  setAdminRole,
  removeAdminRole,
  setSuperAdminRole,
  clearAdminChat,
  designateAsMainAnnouncement,
  removeMainAnnouncement,
  sendFriendRequest,
  acceptFriendRequest,
  rejectOrRemoveFriend,
  clearStaleAdminSessions,
  searchUsersWithStatus,
  deleteEventChallenge, // ⭐️ (14)

  // ✅ [기존] 친구 대결 (실시간) 함수 3개
  sendFriendBattleRequest,      // ⭐️ (15)
  respondToFriendBattleRequest, // ⭐️ (16)
  cancelFriendBattle,           // ⭐️ (17)

  // ✅ [신규 추가] 친구 대결 (오프라인) 함수 3개
  sendAsyncBattleRequest,       // ⭐️ (18)
  completeAsyncBattle,          // ⭐️ (19)
  cancelAsyncBattle,            // ⭐️ (20)
};
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 (신규 함수 2/2) ⭐️⭐️⭐️ ] ▲▲▲▲▲