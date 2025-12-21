// =================================================================================================
// [ index.js ] - 메인 파일 (모든 함수들의 출입구)
// =================================================================================================

const admin = require("firebase-admin");

// ▼▼▼▼▼ [ ✨✨✨ 핵심 ✨✨✨ ] ▼▼▼▼▼
// admin.initializeApp()은 다른 require보다 먼저,
// 프로젝트 전체에서 '단 한 번'만 호출되어야 합니다.
admin.initializeApp();
// ▲▲▲▲▲ [ ✨✨✨ 핵심 ✨✨✨ ] ▲▲▲▲▲

// 1. 우리가 만든 "부서" 파일들을 불러옵니다.
// (주의: 헬퍼 파일(helpers.js)은 다른 파일들이 이미 불러갔으므로, 여기서는 부를 필요 없습니다.)
const callableFunctions = require("./callable.js");
const scheduledFunctions = require("./scheduled.js");
const triggerFunctions = require("./triggers.js");

// 2. 불러온 모든 함수들을 'exports'에 한번에 등록합니다.
// (Firebase가 함수들을 인식할 수 있도록 '수출'하는 과정)
Object.assign(
  exports,
  callableFunctions,
  scheduledFunctions,
  triggerFunctions
);