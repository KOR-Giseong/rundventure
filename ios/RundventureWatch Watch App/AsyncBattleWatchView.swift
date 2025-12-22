// AsyncBattleWatchView.swift (신규 파일)

import SwiftUI

struct AsyncBattleWatchView: View {
    @ObservedObject var connector: WatchConnector

    var body: some View {
        TabView {
            // MARK: - 1. 데이터 표시 화면
            VStack(spacing: 8) {
                // 상단: 런 모드
                HStack {
                    Image(systemName: "person.icloud.fill") // 오프라인 대결 아이콘
                        .foregroundColor(.orange)
                    Text("오프라인 대결 중")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                }

                Spacer()

                // 중앙: 핵심 정보 (거리)
                VStack {
                    Text(String(format: "%.2f", connector.kilometers))
                        .font(.system(size: 68, weight: .bold, design: .rounded))
                        .foregroundColor(connector.isPaused ? .gray : .white) // 일시정지 시 회색
                    // 목표 거리 표시
                    // (targetDistanceKm가 0.0이면 " / ?.? km" 대신 " km"만 표시)
                    Text(connector.targetDistanceKm > 0 ? " / \(String(format: "%.1f", connector.targetDistanceKm)) km" : " km")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .offset(y: -8)
                }

                Spacer()

                // 하단: 시간 및 페이스
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("시간")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Text(formatTime(connector.seconds))
                            .fontWeight(.semibold)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("페이스")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Text(formatPace(connector.pace))
                            .fontWeight(.semibold)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                }
                .font(.headline)
                
                // 페이지 넘김 표시
                Image(systemName: "chevron.left.2")
                    .foregroundColor(.gray)
                    .padding(.top, 4)

            }.padding()

            // MARK: - 2. 컨트롤 버튼 화면
            VStack(spacing: 15) {
                // 일시정지 / 재개 버튼 (자유 러닝과 동일)
                Button(action: {
                    if self.connector.isPaused {
                        self.connector.sendResumeCommandToPhone()
                    } else {
                        self.connector.sendPauseCommandToPhone()
                    }
                }) {
                    Image(systemName: connector.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .tint(.orange)
                .frame(width: 80, height: 80)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())


                Spacer().frame(height: 80)
                
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
}
