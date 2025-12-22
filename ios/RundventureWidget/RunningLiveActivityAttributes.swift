import ActivityKit

struct RunningLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var kilometers: Double
        var seconds: Int
        var pace: Double
        var calories: Double
        var isPaused: Bool
    }
    var name: String
}
