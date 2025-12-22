import Foundation
import ActivityKit

struct GhostRunActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 고스트 런에 필요한 데이터
        var time: String
        var distance: String
        var pace: String
        var isPaused: Bool
    }

    // 정적 데이터 (앱 이름 등)
    var appName: String = "Rundventure"
}
