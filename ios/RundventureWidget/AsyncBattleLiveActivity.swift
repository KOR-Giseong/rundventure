import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents // 👈 AppIntents 임포트

// '비동기 대결' (오프라인)을 위한 라이브 액티비티 UI
struct AsyncBattleLiveActivity: Widget {
     
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AsyncBattleActivityAttributes.self) { context in

            VStack(spacing: 16) {
                   
                // --- 1. 상단: 헤더 ---
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.headline)
                        .foregroundColor(.purple) // 비동기 대결 테마 색상 (보라)
                    Text("오프라인 대결")
                        .font(.headline).fontWeight(.bold).foregroundColor(.black)
                     
                    Spacer()
                       
                    // --- 2. [상태별 분기] ---
                    // (A) 완주한 경우
                    if context.state.isMyRunFinished {
                        Text("완주! 🏁")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                       
                    // (B) 일시정지된 경우
                    } else if context.state.isPaused {
                        Button(intent: ResumeRunningIntent()) {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                       
                    // (C) 러닝 중인 경우
                    } else {
                        Button(intent: PauseRunningIntent()) {
                            Image(systemName: "pause.fill")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                 
                // --- 3. [상태별 분기] ---
                // (A) 완주한 경우: '기록 전송 중' 표시
                if context.state.isMyRunFinished {
                    VStack(spacing: 8) {
                        Text("기록을 전송합니다...")
                            .font(.title2).fontWeight(.bold)
                            .foregroundColor(.black) // ⭐️ [수정] 흰색 -> 검은색
                        Text("앱을 열어 최종 결과를 확인하세요.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 20)
                 
                // (B) 러닝 또는 일시정지 중인 경우: 1인용 프로그레스 바 표시
                } else {
                    VStack(spacing: 8) {
                        // (1) 진행률 텍스트
                        let targetKm = context.attributes.targetDistanceKm
                        let myProgressPercent = (targetKm > 0) ? (context.state.kilometers / targetKm) * 100 : 0.0
                         
                        Text("목표 달성률: \(String(format: "%.1f", myProgressPercent))%")
                            .font(.title3).fontWeight(.bold)
                            .foregroundColor(.black)
                         
                        // (2) 프로그레스 바
                        let myProgress = (targetKm > 0) ? (context.state.kilometers / targetKm) : 0.0
                         
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // 배경 바
                                Capsule().frame(height: 10).foregroundColor(.gray.opacity(0.3)) // 투명도 변경
                                 
                                // 내 바
                                Capsule().frame(width: max(0, myProgress * geometry.size.width), height: 10)
                                    .foregroundColor(.purple)
                            }
                            .clipShape(Capsule())
                        }
                        .frame(height: 10)
                         
                        // (3) 목표 거리 텍스트
                        HStack {
                            Text("0km").font(.caption2).foregroundColor(.gray)
                            Spacer()
                            Text("\(String(format: "%.0f", targetKm))km")
                                .font(.caption2).foregroundColor(.gray)
                        }
                         
                        // (4) 상세 스탯
                        HStack(spacing: 20) {
                            VStack {
                                Text("시간").font(.caption).foregroundColor(.gray)
                                Text(formatTime(context.state.seconds))
                                    .font(.title3).fontWeight(.bold).foregroundColor(.black)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                             
                            VStack {
                                Text("거리").font(.caption).foregroundColor(.gray)
                                Text("\(String(format: "%.2f", context.state.kilometers)) km")
                                    .font(.title3).fontWeight(.bold).foregroundColor(.black)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                             
                            VStack {
                                Text("페이스").font(.caption).foregroundColor(.gray)
                                Text(formatPace(context.state.pace))
                                    .font(.title3).fontWeight(.bold).foregroundColor(.black)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 10)
                    }
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
                        Text("거리").font(.caption2).foregroundColor(.white.opacity(0.6))
                        Text("\(String(format: "%.2f", context.state.kilometers)) km")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("페이스").font(.caption2).foregroundColor(.white.opacity(0.6))
                        Text(formatPace(context.state.pace))
                            .font(.subheadline).fontWeight(.semibold)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // (A) 완주한 경우
                    if context.state.isMyRunFinished {
                        Text("완주! 기록 전송 중... 🏁")
                            .font(.footnote)
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                     
                    // (B) 러닝 또는 일시정지 중인 경우
                    } else {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.purple)
                            Text(formatTime(context.state.seconds))
                             
                            Spacer()
                             
                            if context.state.isPaused {
                                Button(intent: ResumeRunningIntent()) {
                                    Image(systemName: "play.fill")
                                        .font(.title3).padding(8).background(Color.green).foregroundColor(.black).clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(intent: PauseRunningIntent()) {
                                    Image(systemName: "pause.fill")
                                        .font(.title3).padding(8).background(Color.orange).foregroundColor(.black).clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .font(.footnote)
                    }
                }
            }
             
            // --- Compact (축소) ---
            compactLeading: {
                // (A) 완주한 경우
                if context.state.isMyRunFinished {
                    Image(systemName: "flag.checkered")
                        .foregroundColor(.green)
                // (B) 러닝 또는 일시정지 중인 경우
                } else {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.purple)
                }
            }
            compactTrailing: {
                // (A) 완주한 경우
                if context.state.isMyRunFinished {
                    Text("전송 중")
                        .font(.caption)
                        .foregroundColor(.green)
                // (B) 러닝 또는 일시"
                } else {
                    Text(formatPace(context.state.pace))
                        .font(.caption).fontWeight(.medium)
                }
            }
             
            // --- Minimal (AOD) ---
            minimal: {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
            }
            .keylineTint(Color.purple.opacity(0.8))
        }
    }
}
