// FriendBattleWatchView.swift (오류 수정됨)

import SwiftUI

struct FriendBattleWatchView: View {
    @ObservedObject var connector: WatchConnector

    @GestureState private var isPressingStop = false // 종료 버튼 롱프레스 상태
    
    // 나와 상대방의 진행률 (0.0 ~ 1.0)
    private var myProgress: Double {
        // 목표 거리가 0이면 0을 반환 (0으로 나누기 방지)
        guard connector.targetDistanceKm > 0 else { return 0.0 }
        // clamp(0.0, 1.0) 대신 min(..., 1.0) 사용 (목표 초과 시 1.0)
        return min(connector.kilometers / connector.targetDistanceKm, 1.0)
    }
    
    private var opponentProgress: Double {
        guard connector.targetDistanceKm > 0 else { return 0.0 }
        return min(connector.opponentKilometers / connector.targetDistanceKm, 1.0)
    }
    
    // 리드/낙오 거리 (미터 단위)
    private var distanceDifference: Double {
        return (connector.kilometers - connector.opponentKilometers) * 1000
    }

    var body: some View {
        TabView {
            // MARK: - 1. 데이터 표시 화면 (실시간 비교)
            VStack(spacing: 8) {
                // 상단: 런 모드
                HStack {
                    Image(systemName: "person.2.fill") // 실시간 대결 아이콘
                        .foregroundColor(.blue)
                    Text("실시간 대결 중")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                }

                Spacer(minLength: 12)

                // 중앙: 거리 비교 프로그레스 바
                VStack(spacing: 4) {
                    // 1. 내 프로그레스 바
                    ProgressView(value: myProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    HStack {
                        Text("나")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Text(String(format: "%.2f km", connector.kilometers))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    // 2. 상대방 프로그레스 바
                    ProgressView(value: opponentProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                        .padding(.top, 8)
                    HStack {
                        Text(connector.opponentNickname) // 상대방 닉네임
                            .font(.caption)
                            .foregroundColor(.purple)
                            .lineLimit(1) // 닉네임 길면 자름
                        Spacer()
                        Text(String(format: "%.2f km", connector.opponentKilometers))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer(minLength: 12)

                // 하단: 시간, 페이스, 격차
                HStack(alignment: .center, spacing: 12) {
                    VStack {
                        Text("시간")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatTime(connector.seconds))
                            .font(.headline)
                            .fontWeight(.medium)
                            .minimumScaleFactor(0.8) // 폰트 크기 자동 축소
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("페이스")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatPace(connector.pace))
                            .font(.headline)
                            .fontWeight(.medium)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("격차 (m)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatDifference(distanceDifference))
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(differenceColor(distanceDifference))
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 8)
                
                // 페이지 넘김 표시
                Image(systemName: "chevron.left.2")
                    .foregroundColor(.gray)

            }.padding()

            // MARK: - 2. 컨트롤 버튼 화면
            VStack(spacing: 15) {
                // 🚨 [핵심] 실시간 대결은 '일시정지'가 없습니다.
                Spacer().frame(height: 80)

                // '종료' (기권) 버튼 (롱프레스)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 6) // 배경 링

                    // 진행률 표시 링
                    Circle()
                        .trim(from: 0, to: isPressingStop ? 1.0 : 0.0)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 2), value: isPressingStop)

                    // 정지 아이콘
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .foregroundColor(.red)
                }
                .frame(width: 80, height: 80)
                .gesture(
                    LongPressGesture(minimumDuration: 2) // 2초 길게 누르기
                        .updating($isPressingStop) { currentState, gestureState, transaction in
                            gestureState = currentState // 누르는 동안 상태 업데이트
                        }
                        .onEnded { _ in
                            // 2초 성공 시 폰으로 종료(기권) 명령 전송
                            print("✅ Long Press Succeeded. Sending stop command.")
                            self.connector.sendStopCommandToPhone()
                        }
                )
            } // VStack End
        } // TabView End
        .tabViewStyle(.page(indexDisplayMode: .never)) // 페이지 인디케이터 숨김
    } // body End

    // --- Helper 함수들 ---

    // 시간 포맷 함수 (HH:MM:SS)
    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // 페이스 포맷 함수 (M'SS")
    private func formatPace(_ pace: Double) -> String {
        if pace.isInfinite || pace.isNaN || pace <= 0 { return "--'--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        if seconds == 60 {
            return String(format: "%d'00\"", minutes + 1)
        } else {
            return String(format: "%d'%02d\"", minutes, seconds)
        }
    }
    
    // 격차 포맷 함수 (+120m, -30m, 0m)
    private func formatDifference(_ diff: Double) -> String {
        // ▼▼▼▼▼ [ ✅ 여기!! 오류 수정 ] ▼▼▼▼▼
        if abs(diff) < 1 { return "0m" } // 1m 미만은 0 (diff.abs() -> abs(diff))
        // ▲▲▲▲▲ [ ✅ 오류 수정 완료 ] ▲▲▲▲▲
        return String(format: "%@%.0fm", diff > 0 ? "+" : "", diff)
    }
    
    // 격차 색상 (리드: 파랑, 낙오: 보라)
    private func differenceColor(_ diff: Double) -> Color {
        if diff > 0 { return .blue }
        if diff < 0 { return .purple }
        return .white
    }
}
