import AppIntents
import Foundation

// ✅ 1. '일시정지' 명령 정의
struct PauseRunningIntent: AppIntent {
    // 시스템이 이 Intent를 식별하는 이름
    static var title: LocalizedStringResource = "Pause Running"

    // 버튼을 눌렀을 때 실행될 함수
    func perform() async throws -> some IntentResult {
        print("🏃‍♂️ [AppIntent] PauseRunningIntent가 잠금화면에서 실행됨!")
        
        // AppDelegate가 들을 수 있도록 시스템에 "일시정지 해줘"라는 알림(Notification)을 보냅니다.
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.rundventure.pause" as CFString),
            nil,
            nil,
            true // 즉시 전달
        )
        return .result()
    }
}

// ✅ 2. '재개' 명령 정의
struct ResumeRunningIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Running"

    func perform() async throws -> some IntentResult {
        print("🏃‍♂️ [AppIntent] ResumeRunningIntent가 잠금화면에서 실행됨!")
        
        // AppDelegate가 들을 수 있도록 시스템에 "재개 해줘"라는 알림(Notification)을 보냅니다.
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.rundventure.resume" as CFString),
            nil,
            nil,
            true // 즉시 전달
        )
        return .result()
    }
}
