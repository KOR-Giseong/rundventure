import Foundation

// Watch 앱 러닝 뷰에서 공통으로 사용하는 포맷 헬퍼 함수

/// 초(Int)를 HH:MM:SS 형식으로 변환
func formatTime(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

/// 밀리초(Int)를 H:MM:SS.ss 또는 MM:SS.ss 형식으로 변환
func formatTimeWithMs(_ totalMs: Int) -> String {
    let totalSeconds = totalMs / 1000
    let ms = (totalMs % 1000) / 10
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, ms)
    } else {
        return String(format: "%02d:%02d.%02d", minutes, seconds, ms)
    }
}

/// 페이스(Double, 분/km)를 M'SS" 형식으로 변환
func formatPace(_ pace: Double) -> String {
    if pace.isInfinite || pace.isNaN || pace <= 0 { return "--'--" }
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    if seconds == 60 { return String(format: "%d'00\"", minutes + 1) }
    return String(format: "%d'%02d\"", minutes, seconds)
}
