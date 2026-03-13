import ActivityKit
import WidgetKit
import SwiftUI

// '실시간 친구 대결'을 위한 라이브 액티비티 UI
struct FriendBattleLiveActivity: Widget {
     
    // 거리(Double)를 소수점 두 자리 문자열로 변환
    private func formatDist(_ dist: Double) -> String {
        return String(format: "%.2f", dist)
    }
     
    // 리드/낙오 텍스트와 색상을 계산하는 헬퍼 함수
    private func getDiffStatus(myKm: Double, oppKm: Double, isMyFinished: Bool) -> (text: String, color: Color) {
        if isMyFinished {
            return ("완주! 🏁", .green)
        }
         
        let diff = myKm - oppKm
        let diffMeters = Int(abs(diff * 1000))
         
        if abs(diff) < 0.01 { // 10m 이내
            return ("박빙!", .black)
        } else if diff > 0 {
            return ("+\(diffMeters)m 리드", .cyan)
        } else {
            return ("-\(diffMeters)m 낙오", .purple)
        }
    }
     
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FriendBattleActivityAttributes.self) { context in
             

            VStack(spacing: 16) {
                   
                // --- 1. 헤더 ---
                HStack {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text("실시간 친구 대결")
                        .font(.headline).fontWeight(.bold).foregroundColor(.black)
                    Spacer()
                    Text(formatTime(context.state.mySeconds))
                        .font(.headline).fontWeight(.bold).foregroundColor(.black)
                        .minimumScaleFactor(0.8) // 시간이 길어질 경우 대비
                }

                VStack(spacing: 8) {
                       
                    // (1) 리드/낙오 텍스트
                    let diffStatus = getDiffStatus(
                        myKm: context.state.myKilometers,
                        oppKm: context.state.opponentDistance,
                        isMyFinished: context.state.isMyRunFinished
                    )
                    Text(diffStatus.text)
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(diffStatus.color)
                       
                    // (2) 프로그레스 바
                    let targetKm = context.attributes.targetDistanceKm
                    let myProgress = (targetKm > 0) ? (context.state.myKilometers / targetKm) : 0.0
                    let oppProgress = (targetKm > 0) ? (context.state.opponentDistance / targetKm) : 0.0
                     
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 배경 바
                            Capsule().frame(height: 10).foregroundColor(.gray.opacity(0.3))
                             
                            // 상대방 바 (ZStack이므로 뒤에 그림)
                            Capsule().frame(width: max(0, oppProgress * geometry.size.width), height: 10)
                                .foregroundColor(.purple)
                             
                            // 내 바 (앞에 그림)
                            Capsule().frame(width: max(0, myProgress * geometry.size.width), height: 10)
                                .foregroundColor(.cyan)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 10)
                       
                    // (3) 목표 거리 텍스트
                    HStack {
                        Text("0km").font(.caption2).foregroundColor(.gray)
                        Spacer()
                        Text("\(String(format: "%.0f", context.attributes.targetDistanceKm))km")
                            .font(.caption2).foregroundColor(.gray)
                    }
                }

                HStack(alignment: .top) {
                    // (나)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("나")
                            .font(.title3).fontWeight(.bold).foregroundColor(.cyan)
                        Text("\(formatDist(context.state.myKilometers)) km")
                            .font(.title2).fontWeight(.semibold).foregroundColor(.black)
                        Text(formatPace(context.state.myPace))
                            .font(.title3).fontWeight(.medium).foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                       
                    // (상대방)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(context.state.opponentNickname)
                            .font(.title3).fontWeight(.bold).foregroundColor(.purple).lineLimit(1)
                        Text("\(formatDist(context.state.opponentDistance)) km")
                            .font(.title2).fontWeight(.semibold).foregroundColor(.black)
                         
                        if context.state.isOpponentFinished {
                            Text("완주! 🏁")
                                .font(.title3).fontWeight(.medium).foregroundColor(.green)
                        } else {
                            // 상대방 페이스는 실시간성이 떨어져 혼란을 줄 수 있으므로 거리만 표시
                            Text("러닝 중")
                                .font(.title3).fontWeight(.medium).foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(20)
            .background(Color.white)
             
             
        } dynamicIsland: { context in
             
            // MARK: - 다이나믹 아일랜드 (Dynamic Island)
            // (다이나믹 아일랜드는 어두운 배경이 강제되므로 기존 디자인 유지)
            DynamicIsland {
                // --- Expanded (확장) ---
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("나").font(.caption).foregroundColor(.cyan)
                        Text("\(formatDist(context.state.myKilometers)) km")
                            .font(.headline).fontWeight(.semibold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.opponentNickname)
                            .font(.caption).foregroundColor(.purple).lineLimit(1)
                        Text("\(formatDist(context.state.opponentDistance)) km")
                            .font(.headline).fontWeight(.semibold)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .center, spacing: 6) {
                        let diffStatus = getDiffStatus(
                            myKm: context.state.myKilometers,
                            oppKm: context.state.opponentDistance,
                            isMyFinished: context.state.isMyRunFinished
                        )
                         
                        // (A) 둘 다 완주
                        if context.state.isMyRunFinished && context.state.isOpponentFinished {
                            Text("대결 종료! 🏁")
                                .font(.headline).fontWeight(.bold).foregroundColor(.green)
                        // (B) 나만 완주
                        } else if context.state.isMyRunFinished {
                            Text("완주! 🏁 상대방 기다리는 중...")
                                .font(.footnote).fontWeight(.semibold).foregroundColor(.green)
                        // (C) 상대방만 완주
                        } else if context.state.isOpponentFinished {
                            Text("상대방 완주! 🏁")
                                .font(.footnote).fontWeight(.semibold).foregroundColor(.orange)
                        // (D) 둘 다 러닝 중
                        } else {
                            Text(diffStatus.text)
                                .font(.footnote).fontWeight(.medium)
                                .foregroundColor(diffStatus.color == .black ? .gray : diffStatus.color) // ⭐️ .white -> .black으로 수정 (흰색 배경용)
                        }
                         
                        // 내 시간 (항상 표시)
                        Text("시간: \(formatTime(context.state.mySeconds))")
                            .font(.caption).foregroundColor(.gray)
                    }
                }
            }
             
            // --- Compact (축소) ---
            compactLeading: {
                Image(systemName: "figure.run.circle.fill")
                    .foregroundColor(.blue)
            }
            compactTrailing: {
                let diffStatus = getDiffStatus(
                    myKm: context.state.myKilometers,
                    oppKm: context.state.opponentDistance,
                    isMyFinished: context.state.isMyRunFinished
                )

                let statusColor = diffStatus.color == .black ? .white : diffStatus.color
                
                Text(diffStatus.text)
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(statusColor)
                    .lineLimit(1)
            }
             
            // --- Minimal (AOD) ---
            minimal: {
                Image(systemName: "figure.run")
                    .foregroundColor(.blue)
            }
            .keylineTint(Color.blue.opacity(0.8))
        }
    }
}
