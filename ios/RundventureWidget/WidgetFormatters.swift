import Foundation

// Widget / Live Activity에서 공통으로 사용하는 포맷 헬퍼 함수

/// 초(Int)를 MM:SS 또는 H:MM:SS 형식으로 변환 (1시간 미만은 MM:SS)
func formatTime(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// 초(Int)를 항상 HH:MM:SS 형식으로 변환 (자유 러닝 위젯용)
func formatTimeFull(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

/// 페이스(Double, 분/km)를 M:SS 형식으로 변환
func formatPace(_ pace: Double) -> String {
    if pace.isInfinite || pace.isNaN || pace == 0.0 { return "--:--" }
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    return String(format: "%d:%02d", minutes, seconds)
}
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// 페이스(Double, 분/km)를 M:SS 형식으로 변환
func formatPace(_ pace: Double) -> String {
    if pace.isInfinite || pace.isNaN || pace == 0.0 { return "--:--" }
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    return String(format: "%d:%02d", minutes, seconds)
}
