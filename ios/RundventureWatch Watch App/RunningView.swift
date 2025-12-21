import SwiftUI

struct RunningView: View {
    @ObservedObject var connector: WatchConnector

    @GestureState private var isPressingStop = false

    var body: some View {
        TabView {
            // MARK: - 1. 데이터 표시 화면
            VStack {
                // 상단: 현재 런 모드 표시 (아이콘 + 텍스트)
                HStack {
                    // ✅⬇️ 아이콘 표시 로직 수정 ⬇️✅
                    // getRunIconName() 결과에 따라 시스템 아이콘 또는 커스텀 이미지 표시
                    if getRunIconName() == "ghostlogo" {
                        Image("ghostlogo") // 에셋 카탈로그의 이미지 사용
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18) // 아이콘 크기 조절 (캡션 텍스트 옆에 맞게)
                            .foregroundColor(getRunIconColor()) // .purple
                    } else {
                        Image(systemName: getRunIconName()) // 시스템 아이콘 사용 (figure.run)
                            .foregroundColor(getRunIconColor()) // .cyan
                    }
                    // ✅⬆️ 아이콘 표시 로직 수정 완료 ⬆️✅

                    Text(getRunModeTitle())
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer() // 오른쪽 정렬
                }
                .padding(.bottom, 2)

                // 고스트 대결 시: 경주 상태 메시지
                if connector.runType == "ghostRace" && !connector.raceStatus.isEmpty {
                    Text(connector.raceStatus)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .padding(.bottom, 4)
                }

                // 중간: 시간 및 페이스
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

                Spacer() // 중앙 거리 표시 공간

                // 중앙 핵심 정보 (거리)
                VStack {
                    Text(String(format: "%.2f", connector.kilometers))
                        .font(.system(size: 68, weight: .bold, design: .rounded))
                        .foregroundColor(connector.isPaused ? .gray : .white) // 일시정지 시 회색
                    Text("킬로미터")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .offset(y: -8)
                }

                Spacer() // 하단 화살표 공간

                // 하단: 페이지 넘김 표시
                Image(systemName: "chevron.left.2")
                    .foregroundColor(.gray)

            }.padding()

            // MARK: - 2. 컨트롤 버튼 화면
            VStack(spacing: 15) {
                // 일시정지 / 재개 버튼 (모든 모드 공통)
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
                .tint(Color(red: 0, green: 0.8, blue: 0.8)) // 버튼 색상
                .frame(width: 80, height: 80)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())

                // 종료 버튼: 고스트 대결("ghostRace")이 아닐 때만 표시
                if connector.runType != "ghostRace" {
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
                                // 2초 성공 시 폰으로 종료 명령 전송
                                print("✅ Long Press Succeeded. Sending stop command.")
                                self.connector.sendStopCommandToPhone()
                            }
                    )
                } else {
                    // 고스트 대결 중일 때는 종료 버튼 자리에 빈 공간
                    Spacer().frame(height: 80)
                }
            } // VStack End
        } // TabView End
        .tabViewStyle(.page(indexDisplayMode: .never)) // 페이지 인디케이터 숨김
    } // body End

    // --- Helper 함수들 ---

    // 현재 런 모드 타이틀 반환 (수정 없음)
    private func getRunModeTitle() -> String {
        switch connector.runType {
        case "ghostRecord":
            return "첫 기록 측정 중"
        case "ghostRace":
            return "고스트 대결 중"
        default: // "freeRun"
            return "자유 러닝 중"
        }
    }

    // ✅⬇️ 현재 런 모드 아이콘 이름 반환 함수 수정 ⬇️✅
    private func getRunIconName() -> String {
        switch connector.runType {
        case "ghostRace": // 고스트 '대결'일 때만 커스텀 이미지 이름 반환
            return "ghostlogo" // 👈 "ghost.fill" 대신 에셋 이름 사용
        default: // "freeRun" 또는 "ghostRecord" (첫 기록)
            return "figure.run" // 나머지는 시스템 아이콘 이름
        }
    }
    // ✅⬆️ 아이콘 이름 반환 함수 수정 완료 ⬆️✅

    // 현재 런 모드 아이콘 색상 반환 (수정 없음 - 고스트 대결 시 보라색, 나머지는 청록색)
    private func getRunIconColor() -> Color {
        switch connector.runType {
        case "ghostRace":
            return .purple
        default: // "freeRun" 또는 "ghostRecord"
            return .cyan
        }
    }

    // 시간 포맷 함수 (HH:MM:SS) (수정 없음)
    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // 페이스 포맷 함수 (M'SS") (수정 없음)
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
} // RunningView End
