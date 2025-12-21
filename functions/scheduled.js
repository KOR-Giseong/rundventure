// =================================================================================================
// [ scheduled.js ] - 정해진 시간에 자동 실행되는 함수 (onSchedule) 모음
// =================================================================================================

// --- 1. 필요한 모듈 임포트 ---
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const functions = require("firebase-functions");

// --- 2. 헬퍼 함수 임포트 (Part 1에서 만듦) ---
const {
  sendPushNotificationOnly,
  deleteDocumentsInBatch, // (필요 시 사용)
  deleteCollection,       // ⭐️ 하위 컬렉션 삭제를 위해 필수
} = require("./helpers.js");

// --- 3. 전역 인스턴스 ---
const db = admin.firestore();


// =================================================================================================
// 예약 함수 (Scheduled Functions)
// =================================================================================================
// (주의: 여기서는 'exports.'를 붙이지 않고, 맨 마지막에 module.exports로 한번에 내보냅니다.)

// (1) 10분마다 이메일 미인증 사용자 삭제 (10분 유예) + ⭐️ 연관 데이터 완전 삭제 추가
const deleteUnverifiedUsers = onSchedule("every 10 minutes", async (event) => {
  const now = Date.now();
  const tenMinutesInMillis = 10 * 60 * 1000;
  let usersToDelete = [];
  let nextPageToken;

  console.log("미인증 사용자 삭제 작업 시작...");

  try {
    // 1. Auth에서 사용자 목록 조회 및 미인증자 필터링
    do {
      const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
      nextPageToken = listUsersResult.pageToken;

      for (const user of listUsersResult.users) {
        if (!user.emailVerified && user.metadata.creationTime && user.email) {
          const creationTime = new Date(user.metadata.creationTime).getTime();
          if ((now - creationTime) >= tenMinutesInMillis) {
            usersToDelete.push({ uid: user.uid, email: user.email });
          }
        }
      }
    } while (nextPageToken);

    if (usersToDelete.length === 0) {
      console.log("삭제할 미인증 사용자가 없습니다.");
      return;
    }

    console.log(`총 ${usersToDelete.length}명의 미인증 사용자 삭제 시도...`);
    let deletedCount = 0;
    let failedCount = 0;

    // 2. 각 사용자에 대해 데이터 정리 후 삭제
    for (const user of usersToDelete) {
      try {
        const email = user.email;
        console.log(`[삭제 진행] ${email} (UID: ${user.uid}) 데이터 정리 시작`);

        // (A) Firestore 유저 문서 조회 (닉네임 확인용)
        const userDocRef = db.collection("users").doc(email);
        const userDocSnap = await userDocRef.get();

        if (userDocSnap.exists) {
          // (B) 닉네임 삭제
          const nickname = userDocSnap.data().nickname;
          if (nickname) {
            await db.collection("nicknames").doc(nickname.toLowerCase()).delete();
            console.log(` - 닉네임 삭제 완료: ${nickname}`);
          }

          // (C) 하위 컬렉션 및 연관 데이터 삭제 (callable.js 로직과 동일하게 적용)
          // 1. 하위 컬렉션 경로들
          const subCollectionsPaths = [
            `users/${email}/activeQuests`,        // 👈 질문하신 퀘스트 목록
            `users/${email}/completedQuestsLog`,
            `users/${email}/friends`,
            `users/${email}/friendRequests`,
            `notifications/${email}/items`,
            `ghostRunRecords/${email}/records`,
            `userRunningGoals/${email}/dailyGoals`,
            `userRunningData/${email}/goals`,
            `userRunningData/${email}/workouts`
          ];

          // userRunningData의 깊은 하위 컬렉션 확인
          const workoutsSnapshot = await db.collection(`userRunningData/${email}/workouts`).get();
          if (!workoutsSnapshot.empty) {
             for (const workoutDoc of workoutsSnapshot.docs) {
               subCollectionsPaths.push(`userRunningData/${email}/workouts/${workoutDoc.id}/records`);
             }
          }

          // 하위 컬렉션 삭제 실행
          const deletionPromises = subCollectionsPaths.map(path => deleteCollection(db, path, 500));
          await Promise.all(deletionPromises);
          console.log(` - 하위 컬렉션 데이터 삭제 완료`);

          // (D) 유저 최상위 문서 삭제
          await userDocRef.delete();

          // (E) 기타 최상위 문서 삭제 (있을 경우)
          const otherCollections = ["userRunningData", "userRunningGoals", "ghostRunRecords", "notifications"];
          for (const col of otherCollections) {
            await db.collection(col).doc(email).delete();
          }

          console.log(` - Firestore 데이터 삭제 완료`);
        } else {
          console.log(` - Firestore 문서가 없어 스킵함`);
        }

        // (F) 마지막으로 Auth 계정 삭제
        await admin.auth().deleteUser(user.uid);
        console.log(`✅ 미인증 계정 완전 삭제 성공: ${email}`);
        deletedCount++;

      } catch (error) {
        console.error(`❌ 미인증 계정 삭제 실패 (${user.email}):`, error);
        failedCount++;
      }
    }
    console.log(`미인증 사용자 삭제 작업 완료: 성공 ${deletedCount}명, 실패 ${failedCount}명`);

  } catch (error) {
    console.error("미인증 사용자 목록 조회 중 오류 발생:", error);
  }
});

// (2) 10분마다 가입 미완료 소셜 계정 삭제 + ⭐️ 연관 데이터 완전 삭제 추가
const deleteIncompleteSocialUsers = onSchedule({
  schedule: "every 10 minutes",
  timeZone: "Asia/Seoul",
}, async (event) => {
  const now = new Date();
  const tenMinutesAgo = new Date(now.getTime() - (10 * 60 * 1000));

  console.log("가입 미완료 소셜 계정 삭제 작업을 시작합니다.");

  let usersToDelete = [];
  let nextPageToken;

  try {
    // 1. 대상 조회
    do {
      const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
      nextPageToken = listUsersResult.pageToken;

      for (const user of listUsersResult.users) {
        if (!user.email) continue;

        const creationTime = new Date(user.metadata.creationTime);
        if (creationTime > tenMinutesAgo) continue;

        const userDocRef = db.collection("users").doc(user.email);
        const userDoc = await userDocRef.get();
        const userData = userDoc.data();

        // 프로필 미완료 (닉네임/생일 없음) 확인
        const isProfileComplete = userDoc.exists && userData?.nickname && userData?.birthdate;

        if (!isProfileComplete) {
          usersToDelete.push({ uid: user.uid, email: user.email });
        }
      }
    } while (nextPageToken);

    if (usersToDelete.length === 0) {
      console.log("삭제할 가입 미완료 소셜 계정이 없습니다.");
      return;
    }

    // 2. 삭제 실행 (위의 deleteUnverifiedUsers와 동일한 로직 적용)
    let deletedCount = 0;
    for (const user of usersToDelete) {
      try {
        const email = user.email;
        console.log(`[삭제 진행] 소셜 미완료 ${email} 정리 시작`);

        const userDocRef = db.collection("users").doc(email);
        const userDocSnap = await userDocRef.get();

        if (userDocSnap.exists) {
          // 닉네임이 혹시라도 생성되어 있다면 삭제
          const nickname = userDocSnap.data().nickname;
          if (nickname) {
            await db.collection("nicknames").doc(nickname.toLowerCase()).delete();
          }

          // 하위 컬렉션 삭제
          const subCollectionsPaths = [
            `users/${email}/activeQuests`,
            `users/${email}/completedQuestsLog`,
            `users/${email}/friends`,
            `users/${email}/friendRequests`,
            `notifications/${email}/items`,
            `ghostRunRecords/${email}/records`,
            `userRunningGoals/${email}/dailyGoals`,
            `userRunningData/${email}/goals`,
            `userRunningData/${email}/workouts`
          ];
          const workoutsSnapshot = await db.collection(`userRunningData/${email}/workouts`).get();
          if (!workoutsSnapshot.empty) {
             for (const workoutDoc of workoutsSnapshot.docs) {
               subCollectionsPaths.push(`userRunningData/${email}/workouts/${workoutDoc.id}/records`);
             }
          }
          await Promise.all(subCollectionsPaths.map(path => deleteCollection(db, path, 500)));

          // 본체 삭제
          await userDocRef.delete();

          // 기타 최상위 문서 삭제
          const otherCollections = ["userRunningData", "userRunningGoals", "ghostRunRecords", "notifications"];
          for (const col of otherCollections) {
            await db.collection(col).doc(email).delete();
          }
        }

        await admin.auth().deleteUser(user.uid);
        console.log(`✅ 소셜 미완료 계정 완전 삭제 성공: ${email}`);
        deletedCount++;
      } catch (e) {
        console.error(`❌ 소셜 미완료 계정 삭제 실패 (${user.email}):`, e);
      }
    }
    console.log(`소셜 미완료 계정 정리 완료: ${deletedCount}명 삭제됨.`);

  } catch (error) {
    console.error("가입 미완료 소셜 계정 정리 작업 중 오류 발생:", error);
  }
});

// (3) 매일 아침 7시 러닝 알림
const dailyRunningReminderMorning = onSchedule({ schedule: "0 7 * * *", timeZone: "Asia/Seoul" }, async (event) => {
  await sendPushNotificationOnly("러닝 시간이 다가왔어요!", "오늘도 러닝으로 상쾌한 하루를 시작해보세요!");
});

// (4) 매일 오후 5시 러닝 알림
const dailyRunningReminderEvening = onSchedule({ schedule: "0 17 * * *", timeZone: "Asia/Seoul" }, async (event) => {
  await sendPushNotificationOnly("퇴근 후 러닝 어떠세요?", "가볍게 스트레스를 날려보는 시간!");
});

// (5) 매일 밤 9시 러닝 알림
const dailyRunningReminderNight = onSchedule({ schedule: "0 21 * * *", timeZone: "Asia/Seoul" }, async (event) => {
  await sendPushNotificationOnly("오늘 러닝 완료하셨나요?", "아직이라면 지금도 늦지 않았어요!");
});


// (6) 매일 0시 0분 - 리더보드 "집계"
const dailyLeaderboardUpdate = onSchedule({
  schedule: "0 0 * * *",
  timeZone: "Asia/Seoul",
  region: "asia-northeast3",
}, async (event) => {
  const db = admin.firestore();
  const batchSize = 500;
  functions.logger.info("매일 리더보드 갱신 작업 시작...");

  try {
    // --- 1. 주간 Top 100 랭킹 계산 및 저장 ---
    functions.logger.info("주간 Top 100 랭킹 계산 및 저장 시작...");
    const weeklyLeaderboardPath = "weeklyLeaderboard/current/users";
    await deleteCollection(db, weeklyLeaderboardPath, batchSize);

    const weeklyTop100 = await db.collection("users")
      .orderBy("weeklyExp", "desc")
      .limit(100)
      .get();

    if (!weeklyTop100.empty) {
      const weeklyBatch = db.batch();
      let rank = 1;
      weeklyTop100.forEach(doc => {
        const data = doc.data();
        const ref = db.collection(weeklyLeaderboardPath).doc(doc.id);
        weeklyBatch.set(ref, {
          rank: rank++,
          nickname: data.nickname || "Unknown",
          weeklyExp: data.weeklyExp || 0,
          userEmail: doc.id
        });
      });
      await weeklyBatch.commit();
      functions.logger.info(`주간 리더보드 Top ${weeklyTop100.size} 갱신 완료.`);
    } else {
      functions.logger.info("주간 랭킹에 표시할 사용자가 없습니다.");
    }

    // --- 2. 월간 Top 100 랭킹 계산 및 저장 ---
    functions.logger.info("월간 Top 100 랭킹 계산 및 저장 시작...");
    const monthlyLeaderboardPath = "monthlyLeaderboard/current/users";
    await deleteCollection(db, monthlyLeaderboardPath, batchSize);

    const monthlyTop100 = await db.collection("users")
      .orderBy("monthlyExp", "desc")
      .limit(100)
      .get();

    if (!monthlyTop100.empty) {
      const monthlyBatch = db.batch();
      let rank = 1;
      monthlyTop100.forEach(doc => {
        const data = doc.data();
        const ref = db.collection(monthlyLeaderboardPath).doc(doc.id);
        monthlyBatch.set(ref, {
          rank: rank++,
          nickname: data.nickname || "Unknown",
          monthlyExp: data.monthlyExp || 0,
          userEmail: doc.id
        });
      });
      await monthlyBatch.commit();
      functions.logger.info(`월간 리더보드 Top ${monthlyTop100.size} 갱신 완료.`);
    } else {
      functions.logger.info("월간 랭킹에 표시할 사용자가 없습니다.");
    }

    functions.logger.info("매일 리더보드 갱신 작업 성공.");

  } catch (error) {
    functions.logger.error("매일 리더보드 갱신 작업 중 오류 발생:", error);
  }
});


// (7) 매주 월요일 0시 5분 - 주간 점수 "리셋"
const weeklyRankingReset = onSchedule({
  schedule: "5 0 * * 1",
  timeZone: "Asia/Seoul",
  region: "asia-northeast3",
}, async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const batchSize = 500;

  const today = new Date();
  const dateString = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;

  functions.logger.info("주간 랭킹 '리셋' 및 '지난주 Top 3' 집계 작업 시작...");

  try {
    // --- 1. 지난주 Top 3 선정 (리셋 직전 데이터) ---
    const top3Snapshot = await db.collection("users")
      .orderBy("weeklyExp", "desc")
      .limit(3)
      .get();

    const previousWeekWinners = [];
    const weeklyHistoryUpdates = [];
    let rank = 1;

    top3Snapshot.forEach(doc => {
      const data = doc.data();
      const exp = data.weeklyExp || 0;

      previousWeekWinners.push({
        nickname: data.nickname || "Unknown",
        exp: exp,
        userEmail: doc.id
      });

      weeklyHistoryUpdates.push({
        userDocRef: doc.ref,
        entry: {
          rank: rank++,
          week: dateString,
          exp: exp,
        }
      });
    });

    // --- 2. 지난주 Top 3 정보 저장 (metadata) ---
    await db.collection("metadata").doc("previousWeekWinners").set({
      winners: previousWeekWinners,
      updatedAt: now,
    }, { merge: true });
    functions.logger.info("지난주 Top 3 정보 저장 완료:", previousWeekWinners);

    // --- 3. 개인 유저 문서에 주간 랭킹 기록(weeklyHistory) 저장 ---
    if (weeklyHistoryUpdates.length > 0) {
      const historyBatch = db.batch();
      weeklyHistoryUpdates.forEach(update => {
        historyBatch.update(update.userDocRef, {
          weeklyHistory: admin.firestore.FieldValue.arrayUnion(update.entry)
        });
      });
      await historyBatch.commit();
      functions.logger.info(`개인별 주간 랭킹 기록(weeklyHistory) ${weeklyHistoryUpdates.length}명 저장 완료.`);
    }

    // --- 4. 모든 사용자의 weeklyExp 리셋 ---
    functions.logger.info("모든 사용자 weeklyExp 리셋 시작...");
    let totalUsersProcessed = 0;
    let lastUserEmail = null;

    while (true) {
      let query = db.collection("users")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(batchSize);

      if (lastUserEmail) {
        query = query.startAfter(lastUserEmail);
      }

      const usersSnapshot = await query.get();
      if (usersSnapshot.empty) {
        break;
      }

      const resetBatch = db.batch();
      let currentBatchSize = 0;
      usersSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.weeklyExp !== undefined && data.weeklyExp > 0) {
          resetBatch.update(doc.ref, {
            weeklyExp: 0,
            lastExpResetTimestamp: now,
          });
          currentBatchSize++;
        } else if (data.lastExpResetTimestamp === undefined) {
          resetBatch.update(doc.ref, {
            lastExpResetTimestamp: now,
          });
          currentBatchSize++;
        }
      });

      if (currentBatchSize > 0) {
        await resetBatch.commit();
        functions.logger.info(`사용자 ${currentBatchSize}명의 weeklyExp 리셋 또는 타임스탬프 업데이트 완료...`);
      }

      totalUsersProcessed += usersSnapshot.size;
      lastUserEmail = usersSnapshot.docs[usersSnapshot.size - 1].id;

      functions.logger.info(`사용자 ${usersSnapshot.size}명 조회 완료 (총 ${totalUsersProcessed}명)...`);
    }

    // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 핵심 수정: 리셋 후, 전시용 랭킹판 삭제 ⭐️⭐️⭐️ ] ▼▼▼▼▼
    // 유저들의 점수가 0이 되었으므로, 00:00에 생성된 '지난주 점수 기반 랭킹판'을 삭제해야 합니다.
    functions.logger.info("리셋 완료. 전시용 주간 리더보드(weeklyLeaderboard) 초기화(삭제) 시작...");
    await deleteCollection(db, "weeklyLeaderboard/current/users", batchSize);
    functions.logger.info("전시용 주간 리더보드 삭제 완료.");
    // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 핵심 수정 끝 ⭐️⭐️⭐️ ] ▲▲▲▲▲

    functions.logger.info(`주간 랭킹 리셋 작업 성공 완료 (총 ${totalUsersProcessed}명 조회).`);

  } catch (error) {
    functions.logger.error("주간 랭킹 리셋 작업 중 오류 발생:", error);
  }
});


// (8) 매월 1일 0시 10분 - 월간 점수 "리셋"
const monthlyRankingReset = onSchedule({
  schedule: "10 0 1 * *",
  timeZone: "Asia/Seoul",
  region: "asia-northeast3",
}, async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const batchSize = 500;

  const lastMonth = new Date(now.toDate().getTime());
  lastMonth.setMonth(lastMonth.getMonth() - 1);
  const lastMonthString = `${lastMonth.getFullYear()}-${(lastMonth.getMonth() + 1).toString().padStart(2, '0')}`;

  functions.logger.info(`월간 랭킹 '리셋' 및 '명예의 전당'(${lastMonthString}) 기록 작업 시작...`);

  try {
    // --- 1. 지난달 Top 3 선정 (monthlyExp 기준) ---
    const top3Snapshot = await db.collection("users")
      .orderBy("monthlyExp", "desc")
      .limit(3)
      .get();

    const previousMonthWinners = [];
    const hallOfFameUpdates = [];
    let rank = 1;

    top3Snapshot.forEach(doc => {
      const data = doc.data();
      const exp = data.monthlyExp || 0;
      const nickname = data.nickname || "Unknown";
      const userEmail = doc.id;

      previousMonthWinners.push({
        nickname: nickname,
        exp: exp,
        userEmail: userEmail,
      });

      hallOfFameUpdates.push({
        userDocRef: doc.ref,
        entry: {
          rank: rank++,
          month: lastMonthString,
          exp: exp,
        }
      });
    });

    // --- 2. 지난달 Top 3 정보 저장 (metadata) ---
    await db.collection("metadata").doc("previousMonthWinners").set({
      winners: previousMonthWinners,
      month: lastMonthString,
      updatedAt: now,
    }, { merge: true });
    functions.logger.info(`지난달(${lastMonthString}) Top 3 정보 저장 완료:`, previousMonthWinners);

    // --- 3. 명예의 전당 기록 (users/{email} 문서 업데이트) ---
    if (hallOfFameUpdates.length > 0) {
      const hallOfFameBatch = db.batch();
      hallOfFameUpdates.forEach(update => {
        hallOfFameBatch.update(update.userDocRef, {
          hallOfFame: admin.firestore.FieldValue.arrayUnion(update.entry)
        });
      });
      await hallOfFameBatch.commit();
      functions.logger.info(`명예의 전당 ${hallOfFameUpdates.length}명 기록 완료.`);
    }

    // --- 4. 모든 사용자의 monthlyExp 리셋 ---
    functions.logger.info("모든 사용자 monthlyExp 리셋 시작...");
    let totalUsersProcessed = 0;
    let lastUserEmail = null;

    while (true) {
      let query = db.collection("users")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(batchSize);

      if (lastUserEmail) {
        query = query.startAfter(lastUserEmail);
      }

      const usersSnapshot = await query.get();
      if (usersSnapshot.empty) {
        break;
      }

      const resetBatch = db.batch();
      let currentBatchSize = 0;
      usersSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.monthlyExp !== undefined && data.monthlyExp > 0) {
          resetBatch.update(doc.ref, {
            monthlyExp: 0,
          });
          currentBatchSize++;
        }
      });

      if (currentBatchSize > 0) {
        await resetBatch.commit();
        functions.logger.info(`사용자 ${currentBatchSize}명의 monthlyExp 리셋 완료...`);
      }

      totalUsersProcessed += usersSnapshot.size;
      lastUserEmail = usersSnapshot.docs[usersSnapshot.size - 1].id;

      functions.logger.info(`사용자 ${usersSnapshot.size}명 조회 완료 (총 ${totalUsersProcessed}명)...`);
    }

    // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 핵심 수정: 리셋 후, 전시용 랭킹판 삭제 ⭐️⭐️⭐️ ] ▼▼▼▼▼
    // 유저들의 점수가 0이 되었으므로, 00:00에 생성된 '지난달 점수 기반 랭킹판'을 삭제해야 합니다.
    functions.logger.info("리셋 완료. 전시용 월간 리더보드(monthlyLeaderboard) 초기화(삭제) 시작...");
    await deleteCollection(db, "monthlyLeaderboard/current/users", batchSize);
    functions.logger.info("전시용 월간 리더보드 삭제 완료.");
    // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 핵심 수정 끝 ⭐️⭐️⭐️ ] ▲▲▲▲▲

    functions.logger.info(`월간 랭킹 리셋 및 집계 작업 성공 완료 (총 ${totalUsersProcessed}명 조회).`);

  } catch (error) {
    functions.logger.error("월간 랭킹 리셋 작업 중 오류 발생:", error);
  }
});


// (9) 10분마다 종료된 이벤트 챌린지가 있는지 확인 (로직 2단계로 분리)
const checkEventChallengesCompletion = onSchedule({
  schedule: "every 10 minutes",
  timeZone: "Asia/Seoul",
  region: "asia-northeast3",
}, async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const batch = db.batch();
  let changedCount = 0;

  functions.logger.info("이벤트 챌린지 상태 업데이트 작업 시작...");

  // --- 1단계: 'active' -> 'calculating' (집계 대기) ---
  const activeQuery = db.collection("eventChallenges")
      .where("status", "==", "active")
      .where("endDate", "<=", now);

  try {
    const activeSnapshot = await activeQuery.get();
    if (!activeSnapshot.empty) {
      activeSnapshot.forEach(eventDoc => {
        functions.logger.info(`[${eventDoc.id}] 이벤트 종료. 'calculating' (순위 집계 대기) 상태로 변경합니다.`);
        batch.update(eventDoc.ref, {
          status: "calculating",
          aggregationTime: now,
        });
        changedCount++;
      });
    }
  } catch (error) {
    functions.logger.error("1단계 ('active' -> 'calculating') 처리 중 오류:", error);
  }

  // --- 2단계: 'calculating' -> 'ended' (집계 완료) ---
  const calculatingQuery = db.collection("eventChallenges")
      .where("status", "==", "calculating");

  const aggregationWaitTime = 10 * 60 * 1000; // 10 minutes

  try {
    const calculatingSnapshot = await calculatingQuery.get();
    if (calculatingSnapshot.empty && changedCount === 0) {
      functions.logger.info("상태를 변경할 이벤트 챌린지가 없습니다.");
      if (changedCount > 0) await batch.commit();
      return null;
    }

    if (changedCount > 0) {
        await batch.commit();
        functions.logger.info(`총 ${changedCount}개의 이벤트를 'calculating' 상태로 변경했습니다.`);
    }

    for (const eventDoc of calculatingSnapshot.docs) {
      const eventId = eventDoc.id;
      const data = eventDoc.data();
      const aggregationTime = data.aggregationTime;

      if (!aggregationTime || (now.toMillis() - aggregationTime.toMillis()) < aggregationWaitTime) {
        functions.logger.log(`[${eventId}] 순위 집계 대기 중... (10분 경과 필요)`);
        continue;
      }

      functions.logger.info(`[${eventId}] 순위 집계 대기 시간(10분) 경과. 순위 집계 및 'ended' 상태 변경 시작...`);

      try {
        const participantsSnap = await eventDoc.ref.collection("participants").get();
        let topRunner = null;
        let luckyRunner = null;
        const winners = {};

        if (participantsSnap.empty) {
          functions.logger.info(`[${eventId}] 참여자가 없어 순위 집계를 건너뜁니다.`);
          await eventDoc.ref.update({ status: "ended", winners: {} });
          continue;
        }

        const participants = [];
        participantsSnap.forEach(doc => {
          participants.push(doc.data());
        });

        participants.sort((a, b) => (b.totalDistance || 0) - (a.totalDistance || 0));
        const topRunnerData = participants[0];
        topRunner = {
          email: topRunnerData.email,
          nickname: topRunnerData.nickname,
          distance: topRunnerData.totalDistance || 0.0,
        };
        winners.topRunner = topRunner;

        const otherParticipants = participants.filter(p => p.email !== topRunner.email);
        if (otherParticipants.length > 0) {
          const randomIndex = Math.floor(Math.random() * otherParticipants.length);
          const luckyRunnerData = otherParticipants[randomIndex];
          luckyRunner = {
            email: luckyRunnerData.email,
            nickname: luckyRunnerData.nickname,
            distance: luckyRunnerData.totalDistance || 0.0,
          };
        } else {
          luckyRunner = topRunner;
        }
        winners.luckyRunner = luckyRunner;

        await eventDoc.ref.update({
          status: "ended",
          winners: winners,
        });

        functions.logger.info(`[${eventId}] 이벤트 순위 집계 완료. Top: ${topRunner.email}, Lucky: ${luckyRunner.email}`);

      } catch (error) {
        functions.logger.error(`[${eventId}] 이벤트 순위 집계 중 오류 발생:`, error);
        continue;
      }
    }
  } catch (error) {
    functions.logger.error("2단계 ('calculating' -> 'ended') 처리 중 오류:", error);
  }

  return null;
});


// (10) 매일 아침 9시 생일자 확인 및 축하 알림 발송 [🔥 신규 추가됨 🔥]
const checkDailyBirthdays = onSchedule({
  schedule: "0 9 * * *", // 매일 아침 9시 실행
  timeZone: "Asia/Seoul",
  region: "asia-northeast3",
  timeoutSeconds: 300, // 5분 제한
}, async (event) => {
  const db = admin.firestore();
  const now = new Date();

  // 한국 시간 기준으로 월/일 계산 (Node.js 환경은 기본 UTC이므로 9시간 더함)
  const kstOffset = 9 * 60 * 60 * 1000;
  const kstDate = new Date(now.getTime() + kstOffset);

  const month = String(kstDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(kstDate.getUTCDate()).padStart(2, '0');
  const targetSuffix = `-${month}-${day}`; // 예: "-11-11"

  functions.logger.info(`[생일 체크] 오늘 날짜: ${month}월 ${day}일 (Suffix: ${targetSuffix}) 검색 시작`);

  try {
    // 1. 모든 사용자 조회
    const usersSnapshot = await db.collection("users").get();

    if (usersSnapshot.empty) {
      functions.logger.info("사용자가 없습니다.");
      return;
    }

    const birthdayUsers = [];

    // 2. 생일자 필터링
    usersSnapshot.forEach(doc => {
      const data = doc.data();
      const birthdate = data.birthdate; // 예: "1995-11-11"

      // birthdate가 존재하고 문자열이며, 오늘 날짜로 끝나는지 확인
      if (birthdate && typeof birthdate === 'string' && birthdate.endsWith(targetSuffix)) {
        birthdayUsers.push({
          email: doc.id,
          nickname: data.nickname || "회원",
          fcmToken: data.fcmToken
        });
      }
    });

    if (birthdayUsers.length === 0) {
      functions.logger.info(`[생일 체크] 오늘 생일인 사용자가 없습니다.`);
      return;
    }

    functions.logger.info(`[생일 체크] 오늘 생일자 ${birthdayUsers.length}명 발견! 알림 전송 시작...`);

    // 3. 알림 전송 및 저장 (Batch 처리)
    const batch = db.batch();
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const notificationPromises = [];

    for (const user of birthdayUsers) {
      const title = "생일 축하합니다! 🎂";
      const message = `${user.nickname}님, 오늘 생일 진심으로 축하드려요! 행복한 하루 보내세요.`;

      // (A) Firestore 알림함에 저장
      const notiRef = db.collection("notifications").doc(user.email).collection("items").doc();
      batch.set(notiRef, {
        type: "admin_personal", // 아이콘 처리를 위해 관리자 알림 타입 사용
        title: title,
        message: message,
        timestamp: timestamp,
        isRead: false,
      });

      // (B) FCM 푸시 알림 전송
      if (user.fcmToken) {
        const pushPromise = admin.messaging().send({
          token: user.fcmToken,
          notification: { title, body: message },
          apns: { payload: { aps: { alert: { title, body: message }, sound: "default", badge: 1 } } },
          data: { screen: "UserNotificationPage" },
        }).catch(e => functions.logger.error(`FCM 전송 실패 (${user.email}):`, e));

        notificationPromises.push(pushPromise);
      }
    }

    // 배치 커밋 및 푸시 전송 대기
    await batch.commit();
    await Promise.all(notificationPromises);

    functions.logger.info(`[생일 체크] 총 ${birthdayUsers.length}명에게 생일 축하 알림 전송 완료.`);

  } catch (error) {
    functions.logger.error("[생일 체크] 작업 중 오류 발생:", error);
  }
});


// --- 4. 정의한 모든 Scheduled 함수들을 내보내기(export) ---
module.exports = {
  deleteUnverifiedUsers,
  deleteIncompleteSocialUsers,
  dailyRunningReminderMorning,
  dailyRunningReminderEvening,
  dailyRunningReminderNight,
  dailyLeaderboardUpdate,
  weeklyRankingReset,
  monthlyRankingReset,
  checkEventChallengesCompletion,
  checkDailyBirthdays, // ⭐️ 신규 추가됨
};