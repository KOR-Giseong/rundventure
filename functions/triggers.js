// =================================================================================================
// =================================================================================================

// --- 1. 필요한 모듈 임포트 ---
const { onDocumentWritten, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const functions = require("firebase-functions"); // v1 로거 사용 시 필요

// --- 2. 전역 인스턴스 ---
const db = admin.firestore();


// =================================================================================================
// Firestore 트리거 함수 (Firestore Trigger Functions)
// =================================================================================================

/**
 * (5) 사용자가 새 러닝 기록을 생성했을 때, 참여 중인 '이벤트 챌린지'의 참여도를 업데이트합니다.
 * 경로: /userRunningData/{userEmail}/workouts/{date}/records/{recordId}
 */
const onNewRunningRecord = onDocumentWritten({
  document: "userRunningData/{userEmail}/workouts/{date}/records/{recordId}",
  region: "asia-northeast3",
}, async (event) => {
  // '생성' 시에만 동작하도록 확인
  if (!event.data || !event.data.after.exists || event.data.before.exists) {
    // functions.logger.log("러닝 기록 생성이 아니므로(수정/삭제) 스킵합니다.");
    return null;
  }

  const recordData = event.data.after.data();
  const userEmail = event.params.userEmail;
  // 'kilometers' 필드가 앱에서 저장하는 필드명과 일치해야 합니다.
  const distanceInKm = recordData.kilometers || 0.0;
  // 러닝 기록 시간을 Firestore Timestamp 객체로 가져옵니다.
  const recordTimestamp = recordData.date; // (이미 Timestamp 객체여야 함)

  if (distanceInKm <= 0) {
    functions.logger.log(`[EventTrigger] ${userEmail} 유저의 거리가 0이하(${distanceInKm}km)이므로 스킵합니다.`);
    return null;
  }

  // recordTimestamp가 유효한 Timestamp가 아니면 중단
  if (!recordTimestamp || typeof recordTimestamp.toDate !== 'function') {
     functions.logger.error(`[EventTrigger] ${userEmail} 유저의 러닝 기록 'date' 필드가 유효한 Timestamp가 아닙니다.`);
     return null;
  }

  try {
    // 1. 'eventChallenges' 컬렉션에서 'active' 상태인 모든 이벤트를 가져옵니다.
    const activeEventsSnap = await db.collection("eventChallenges")
        .where("status", "==", "active")
        .get();

    if (activeEventsSnap.empty) {
      functions.logger.log(`[EventTrigger] 현재 'active' 상태인 이벤트가 없습니다.`);
      return null;
    }

    const batch = db.batch();
    let updatedCount = 0;
    const recordDate = recordTimestamp.toDate();

    // 2. 'active'인 이벤트를 순회하며, 내가 참여자인지 확인합니다.
    for (const eventDoc of activeEventsSnap.docs) {
      const eventId = eventDoc.id;
      const participantRef = db.doc(`eventChallenges/${eventId}/participants/${userEmail}`);

      const participantDoc = await participantRef.get();

      // 3. 내가 이 이벤트의 참여자가 아니면 건너뜁니다.
      if (!participantDoc.exists) {
        continue;
      }

      // 4. 내가 참여자라면, 'joinedAt' 시간을 확인합니다.
      const participantData = participantDoc.data();
      const joinedAtTimestamp = participantData.joinedAt; // 참여한 시간

      // 5. 러닝 기록이 '이벤트 참여 전'이면 건너뜁니다.
      if (joinedAtTimestamp && joinedAtTimestamp.toDate() > recordDate) {
        functions.logger.log(`[EventTrigger] ${eventId} 이벤트 참여(${joinedAtTimestamp.toDate()}) 전의 기록(${recordDate})이므로 스킵.`);
        continue;
      }

      // 6. 모든 조건을 통과하면, 배치에 거리 업데이트를 추가합니다.
      functions.logger.log(`[EventTrigger] ${userEmail} 유저의 ${eventId} 이벤트 참여도 ${distanceInKm}km 추가 중...`);
      batch.update(participantRef, {
        "totalDistance": admin.firestore.FieldValue.increment(distanceInKm)
      });
      updatedCount++;
    }

    // 7. 배치 실행
    if (updatedCount > 0) {
      await batch.commit();
      functions.logger.log(`[EventTrigger] ${userEmail} 유저의 이벤트 참여도 ${updatedCount}건 업데이트 완료.`);
    } else {
      functions.logger.log(`[EventTrigger] ${userEmail} 유저의 러닝 기록은 있지만, 업데이트할 유효한 이벤트가 없습니다. (참여 전 기록일 수 있음)`);
    }

    return null;

  } catch (error) {
    functions.logger.error(`[EventTrigger] ${userEmail} 유저의 이벤트 참여도 집계 중 심각한 오류 발생:`, error);
    return null;
  }
});


// (3) 챌린지 새 댓글 알림 트리거
const onNewChallengeComment = onDocumentWritten({
  document: "challenges/{challengeId}/comments/{commentId}",
  region: "asia-northeast3",
}, async (event) => {
  // '생성' 시에만 동작하도록 방어 코드 수정
  if (!event.data || !event.data.after.exists || event.data.before.exists) {
    // functions.logger.log("챌린지 댓글 생성(create)이 아니므로 알림을 스킵합니다.");
    return null;
  }

  const commentData = event.data.after.data();
  const challengeId = event.params.challengeId;

  const commenterEmail = commentData.userEmail;
  const commenterName = commentData.userName || "누군가";
  const commentText = commentData.comment || "";
  const imageUrl = commentData.imageUrl || ""; // 이미지 URL 가져오기

  // 1. 챌린지 정보 가져오기
  const challengeRef = db.collection("challenges").doc(challengeId);
  const challengeDoc = await challengeRef.get();

  if (!challengeDoc.exists) {
    functions.logger.error(`챌린지 문서를 찾을 수 없습니다: ${challengeId}`);
    return null;
  }

  const challengeData = challengeDoc.data();
  const challengeName = challengeData.name || "챌린지";
  const challengeAuthorEncoded = challengeData.userEmail || "";

  // 이메일 디코딩
  const challengeAuthorEmail = challengeAuthorEncoded.replace(/_at_/g, "@").replace(/_dot_/g, ".");

  // 참여자 목록
  const participants = challengeData.participants || [];

  // 2. 알림 보낼 사용자 목록 만들기
  const usersToNotify = new Set(participants);
  if (challengeAuthorEmail) {
    usersToNotify.add(challengeAuthorEmail);
  }

  // 3. 알림 배치(Batch) 생성
  const batch = db.batch();
  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  usersToNotify.forEach((emailToNotify) => {
    if (emailToNotify === commenterEmail) {
      return;
    }

    const notificationRef = db
      .collection("notifications")
      .doc(emailToNotify)
      .collection("items")
      .doc(); // 자동 ID

    batch.set(notificationRef, {
      type: "comment",
      userName: commenterName,
      message: commentText,
      title: `${commenterName} 님이 '${challengeName}'에 댓글을 남겼습니다.`,
      challengeId: challengeId,
      challengeName: challengeName,
      commenterEmail: commenterEmail,
      imageUrl: imageUrl,
      timestamp: timestamp,
      isRead: false,
    });
  });

  // 4. 배치 실행
  try {
    await batch.commit();
    functions.logger.info(`챌린지(${challengeId}) 댓글 알림 전송 성공. 대상: ${usersToNotify.size - 1}명`);
    return null;
  } catch (error) {
    functions.logger.error(`챌린지(${challengeId}) 댓글 알림 전송 실패:`, error);
    return null;
  }
});


// (4) 자유게시판 새 댓글 알림 트리거
const onNewFreeTalkComment = onDocumentWritten({
  document: "freeTalks/{postId}/comments/{commentId}",
  region: "asia-northeast3",
}, async (event) => {
  // '생성' 시에만 동작
  if (!event.data || !event.data.after.exists || event.data.before.exists) {
    // functions.logger.log("자유게시판 댓글 생성(create)이 아니므로 알림을 스킵합니다.");
    return null;
  }

  const commentData = event.data.after.data();
  const postId = event.params.postId;

  const commenterEmail = commentData.userEmail;
  const isAnonymous = commentData.isAnonymous === true;
  const commenterName = isAnonymous ? "익명" : (commentData.nickname || "알 수 없음");
  const commentText = commentData.content || "";

  // 1. 게시물 정보 가져오기
  const postRef = db.collection("freeTalks").doc(postId);
  const postDoc = await postRef.get();

  if (!postDoc.exists) {
    functions.logger.error(`자유게시판 문서를 찾을 수 없습니다: ${postId}`);
    return null;
  }

  const postData = postDoc.data();
  const postTitle = postData.title || "게시물";
  const postAuthorEncoded = postData.userEmail || "";

  // 이메일 디코딩
  const postAuthorEmail = postAuthorEncoded.replace(/_at_/g, "@").replace(/_dot_/g, ".");

  // 2. 다른 댓글 작성자들 이메일 가져오기
  const commentsSnapshot = await postRef.collection("comments").get();

  // 3. 알림 보낼 사용자 목록 만들기
  const usersToNotify = new Set();
  if (postAuthorEmail) {
    usersToNotify.add(postAuthorEmail);
  }
  commentsSnapshot.docs.forEach((doc) => {
    const data = doc.data();
    if (data.userEmail) {
      usersToNotify.add(data.userEmail);
    }
  });

  // 4. 알림 배치(Batch) 생성
  const batch = db.batch();
  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  usersToNotify.forEach((emailToNotify) => {
    if (emailToNotify === commenterEmail) {
      return;
    }

    const notificationRef = db
      .collection("notifications")
      .doc(emailToNotify)
      .collection("items")
      .doc(); // 자동 ID

    batch.set(notificationRef, {
      type: "freeTalkComment",
      userName: commenterName,
      message: commentText,
      title: `${commenterName} 님이 '${postTitle}'에 댓글을 남겼습니다.`,
      postId: postId,
      commenterEmail: commenterEmail,
      timestamp: timestamp,
      isRead: false,
    });
  });

  // 5. 배치 실행
  try {
    await batch.commit();
    functions.logger.info(`자유게시판(${postId}) 댓글 알림 전송 성공. 대상: ${usersToNotify.size - 1}명`);
    return null;
  } catch (error) {
    functions.logger.error(`자유게시판(${postId}) 댓글 알림 전송 실패:`, error);
    return null;
  }
});


/**
 * (6) 사용자 프로필(닉네임)이 변경되면, 주간/월간 리더보드에 있는 닉네임도 동기화합니다.
 * 경로: /users/{userEmail}
 */
const onUserInfoUpdated = onDocumentUpdated({
  document: "users/{userEmail}",
  region: "asia-northeast3",
}, async (event) => {
  // 변경 전/후 데이터 가져오기
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  const userEmail = event.params.userEmail;

  // 닉네임이 변경되었는지 확인 (변경 안 됐으면 종료)
  const oldNickname = beforeData.nickname;
  const newNickname = afterData.nickname;

  if (oldNickname === newNickname) {
    return null; // 닉네임이 안 바뀌었으면 아무것도 안 함
  }

  functions.logger.info(`[닉네임 변경 감지] ${userEmail}: ${oldNickname} -> ${newNickname}`);

  const batch = db.batch();
  let updatedCount = 0;

  // 1. 주간 리더보드 문서 참조
  const weeklyRankRef = db.collection("weeklyLeaderboard/current/users").doc(userEmail);
  // 2. 월간 리더보드 문서 참조
  const monthlyRankRef = db.collection("monthlyLeaderboard/current/users").doc(userEmail);

  try {
    // 해당 문서들이 실제로 존재하는지 확인 (랭킹에 없는 유저일 수도 있으므로)
    const [weeklyDoc, monthlyDoc] = await Promise.all([
      weeklyRankRef.get(),
      monthlyRankRef.get()
    ]);

    // 주간 랭킹에 있으면 업데이트 추가
    if (weeklyDoc.exists) {
      batch.update(weeklyRankRef, { nickname: newNickname });
      updatedCount++;
    }

    // 월간 랭킹에 있으면 업데이트 추가
    if (monthlyDoc.exists) {
      batch.update(monthlyRankRef, { nickname: newNickname });
      updatedCount++;
    }

    // 업데이트할 게 있으면 실행
    if (updatedCount > 0) {
      await batch.commit();
      functions.logger.info(`[성공] 리더보드 ${updatedCount}곳의 닉네임 업데이트 완료.`);
    }

  } catch (error) {
    functions.logger.error("리더보드 닉네임 동기화 실패:", error);
  }

  return null;
});


// --- 3. 정의한 모든 Trigger 함수들을 내보내기(export) ---
module.exports = {
  onNewChallengeComment,
  onNewFreeTalkComment,
  onNewRunningRecord,
  onUserInfoUpdated,
};