// [전체 코드] SummaryView.swift

import SwiftUI

struct SummaryView: View {
    @ObservedObject var connector: WatchConnector

    // 그리드 칼럼 정의
    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {

                // 1. 결과 타이틀 (고스트/친구/오프라인 등)
                if connector.runType == "ghostRace" {
                    Text(getGhostRaceResultText())
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(getGhostRaceResultColor())
                        .padding(.bottom, 4)
                
                } else if connector.runType == "friendRace" {
                    Text(getFriendRaceResultText())
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(getFriendRaceResultColor())
                        .padding(.bottom, 4)

                } else if connector.runType == "ghostRecord" {
                    Text("첫 기록 측정 완료!")
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(.cyan)
                        .padding(.bottom, 4)
                        
                } else if connector.runType == "asyncRace" {
                    Text("오프라인 대결 완료!")
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(.orange)
                        .padding(.bottom, 4)
                }
                // (freeRun은 별도 타이틀 없음)
                

                // 2. 헤더: 총 거리
                VStack(alignment: .leading) {
                    Text(String(format: "%.2f", connector.kilometers))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(getMainColor()) // runType별 메인 색상
                    Text("킬로미터")
                        .font(.title3)
                        .fontWeight(.medium)
                }
                .padding(.bottom, 4)

                // 3. 상세 정보 그리드
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {

                    // 밀리초 데이터가 없으면(0이면) 기존 초 데이터를 밀리초로 변환해서 표시
                    let totalMs = connector.milliseconds > 0 ? connector.milliseconds : (connector.seconds * 1000)
                    SummaryGridItem(label: "시간", value: formatTimeWithMs(totalMs)) // 신규 포맷터 사용
                    
                    SummaryGridItem(label: "평균 페이스", value: formatPace(connector.pace))
                    
                    // '실시간 대결'이 아닐 때만 칼로리 표시
                    if connector.runType != "friendRace" {
                        SummaryGridItem(label: "소모 칼로리", value: "\(Int(connector.calories))kcal")
                    }

                    // '오프라인 대결' 또는 '실시간 대결'일 때 '목표 거리' 표시
                    if (connector.runType == "asyncRace" || connector.runType == "friendRace") && connector.targetDistanceKm > 0 {
                        SummaryGridItem(label: "목표 거리", value: "\(String(format: "%.1f", connector.targetDistanceKm))km")
                    }
                    
                    // '실시간 대결'일 때만 '상대방 기록' 표시
                    if connector.runType == "friendRace" {
                        SummaryGridItem(label: connector.opponentNickname, value: String(format: "%.2f km", connector.opponentKilometers))
                    }
                    
                    // (고도 표시는 제거됨)
                }
                .padding(.bottom, 10)


                // 4. 하단 버튼
                if connector.runType == "ghostRace" || connector.runType == "ghostRecord" ||
                   connector.runType == "friendRace" || connector.runType == "asyncRace"
                {
                    // 결과 확인 버튼
                    Button(action: { connector.sendResetCommand() }) {
                        Text("확인")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(getMainColor())
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                } else { // "freeRun" (자유 러닝)
                    HStack(spacing: 10) {
                        Button(action: { connector.sendCancelCommandToPhone() }) {
                            Text("취소")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.gray)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: { connector.sendSaveCommandToPhone() }) {
                            Text("저장")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(getMainColor())
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }

            } // VStack End
            .padding()
        } // ScrollView End
        .navigationBarBackButtonHidden(true)
    } // body End

    // --- Helper 함수들 ---

    private func getMainColor() -> Color {
        switch connector.runType {
        case "ghostRace", "ghostRecord":
            return .cyan
        case "friendRace":
            return .blue
        case "asyncRace":
            return .orange
        default: // "freeRun"
            return .cyan
        }
    }

    // 고스트런 결과 텍스트
    private func getGhostRaceResultText() -> String {
        switch connector.raceOutcome {
        case "win": return "승리! (고스트) 🎉"
        case "lose": return "패배 (고스트) 😥"
        case "tie", "draw": return "무승부 (고스트) 🤝"
        default: return "대결 완료!"
        }
    }
    // 고스트런 결과 색상
    private func getGhostRaceResultColor() -> Color {
        switch connector.raceOutcome {
        case "win": return .green
        case "lose": return .red
        case "tie", "draw": return .indigo
        default: return .gray
        }
    }
    
    // 친구 대결 결과 텍스트
    private func getFriendRaceResultText() -> String {
        switch connector.raceOutcome {
        case "win": return "승리! (친구) 🏆"
        case "lose": return "패배 (친구) 😥"
        case "tie", "draw": return "무승부 (친구) 🤝"
        default: return "대결 완료!"
        }
    }
    // 친구 대결 결과 색상
    private func getFriendRaceResultColor() -> Color {
        switch connector.raceOutcome {
        case "win": return .green
        case "lose": return .red
        case "tie", "draw": return .indigo
        default: return .gray
        }
    }
    
} // SummaryView End

// --- 그리드 아이템 헬퍼 뷰 (수정 없음) ---
struct SummaryGridItem: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
    }
}
