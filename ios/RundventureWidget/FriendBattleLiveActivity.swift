//
//  FriendBattleLiveActivity.swift
//  RundventureWidgetExtension
//
//  Created by (Your Name) on (Current Date).
//

import ActivityKit
import WidgetKit
import SwiftUI

// '실시간 친구 대결'을 위한 라이브 액티비티 UI
struct FriendBattleLiveActivity: Widget {
     
    // 초(Int)를 MM:SS 또는 HH:MM:SS 형식으로 변환
    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
         
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
     
    // 페이스(Double)를 M:SS 형식으로 변환
    private func formatPace(_ pace: Double) -> String {
        if pace.isInfinite || pace.isNaN || pace == 0.0 {
            return "--:--"
        }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
     
    // 거리(Double)를 소수점 두 자리 문자열로 변환
    private func formatDist(_ dist: Double) -> String {
        return String(format: "%.2f", dist)
    }
     
    // ⭐️ [신규 추가] 리드/낙오 텍스트와 색상을 계산하는 헬퍼 함수
    private func getDiffStatus(myKm: Double, oppKm: Double, isMyFinished: Bool) -> (text: String, color: Color) {
        if isMyFinished {
            return ("완주! 🏁", .green)
        }
         
        let diff = myKm - oppKm
        let diffMeters = Int(abs(diff * 1000))
         
        if abs(diff) < 0.01 { // 10m 이내
            return ("박빙!", .black) // ⭐️ [수정] 흰색 -> 검은색
        } else if diff > 0 {
            return ("+\(diffMeters)m 리드", .cyan)
        } else {
            return ("-\(diffMeters)m 낙오", .purple)
        }
    }
     
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FriendBattleActivityAttributes.self) { context in
             
            // MARK: - 잠금화면 UI (Lock Screen) ⭐️ [수정됨]
            // 👈 [수정] ZStack { Color.white ... } 제거
            VStack(spacing: 16) {
                   
                // --- 1. 헤더 ---
                HStack {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.headline)
                        .foregroundColor(.blue) // 친구 대결 테마 색상 (파랑)
                    Text("실시간 친구 대결")
                        .font(.headline).fontWeight(.bold).foregroundColor(.black) // ⭐️ [수정] 흰색 -> 검은색
                    Spacer()
                    // ⭐️ [수정] 내 시간 표시
                    Text(formatTime(context.state.mySeconds))
                        .font(.headline).fontWeight(.bold).foregroundColor(.black) // ⭐️ [수정] 흰색 -> 검은색
                        .minimumScaleFactor(0.8) // 시간이 길어질 경우 대비
                }
                 
                // --- 2. ⭐️ [신규] 거리 비교기 ---
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
                            Capsule().frame(height: 10).foregroundColor(.gray.opacity(0.3)) // ⭐️ [수정] 투명도 변경
                             
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
                 
                // --- 3. ⭐️ [신규] 상세 스탯 (나 vs 상대방) ---
                HStack(alignment: .top) {
                    // (나)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("나")
                            .font(.title3).fontWeight(.bold).foregroundColor(.cyan)
                        Text("\(formatDist(context.state.myKilometers)) km")
                            .font(.title2).fontWeight(.semibold).foregroundColor(.black) // ⭐️ [수정]
                        Text(formatPace(context.state.myPace))
                            .font(.title3).fontWeight(.medium).foregroundColor(.black) // ⭐️ [수정]
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                       
                    // (상대방)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(context.state.opponentNickname)
                            .font(.title3).fontWeight(.bold).foregroundColor(.purple).lineLimit(1)
                        Text("\(formatDist(context.state.opponentDistance)) km")
                            .font(.title2).fontWeight(.semibold).foregroundColor(.black) // ⭐️ [수정]
                         
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
            .background(Color.white) // 👈 [수정] .background(Color.white) 수정자 사용
            // 👈 [수정] ZStack 닫는 '}' 제거
             
             
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
            // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 ⭐️⭐️⭐️ ] ▼▼▼▼▼
            compactTrailing: {
                // ⭐️ [수정] 공간 부족으로 잘리는(0...) 문제를 해결하기 위해
                // getDiffStatus 헬퍼를 사용해 하나의 텍스트로 요약합니다.
                let diffStatus = getDiffStatus(
                    myKm: context.state.myKilometers,
                    oppKm: context.state.opponentDistance,
                    isMyFinished: context.state.isMyRunFinished
                )
                
                // ⭐️ .black는 어두운 DI에서 보이지 않으므로 .white로 변경
                let statusColor = diffStatus.color == .black ? .white : diffStatus.color
                
                Text(diffStatus.text)
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(statusColor)
                    .lineLimit(1) // 👈 만약을 위해 한 줄로 제한
            }
            // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 ⭐️⭐️⭐️ ] ▲▲▲▲▲
             
            // --- Minimal (AOD) ---
            minimal: {
                Image(systemName: "figure.run")
                    .foregroundColor(.blue)
            }
            .keylineTint(Color.blue.opacity(0.8))
        }
    }
}
