import ActivityKit

struct RunningLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var kilometers: Double
        var seconds: Int
        var pace: Double
        var calories: Double
        var isPaused: Bool // ✅ [추가] 일시정지 상태 변수
    }
    var name: String
}
