import Foundation
import ActivityKit

struct GhostRaceActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // '나'의 데이터
        var userTime: String
        var userDistance: String
        var userPace: String
        // '고스트'와의 비교 상태 메시지
        var raceStatus: String
        var isPaused: Bool // ✅ [추가] 일시정지 상태 변수
    }
    var appName: String = "Rundventure"
}
