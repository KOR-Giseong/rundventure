import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct RundventureWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunningLiveActivityAttributes.self) { context in
            // --- 잠금화면 UI ---
            VStack(alignment: .leading, spacing: 8) {
                
                // 상단 HStack: 로고 + Spacer + 버튼
                HStack {
                    // 좌측 로고
                    Image(systemName: "figure.run")
                        .font(.title3)
                        .foregroundColor(.blue)
                    Text("런드벤처")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                    
                    Spacer() // 중간을 밀어냄
                    
                    // 우측 상단 아이콘 버튼 (배경 없음)
                    if context.state.isPaused {
                        Button(intent: ResumeRunningIntent()) {
                            Image(systemName: "play.fill") // 재개 아이콘
                                .font(.title) // 아이콘 크기
                                .foregroundColor(.gray) // 아이콘 색상
                        }
                        .buttonStyle(.plain) // 모든 기본 스타일 제거
                    } else {
                        Button(intent: PauseRunningIntent()) {
                            Image(systemName: "pause.fill") // 일시정지 아이콘
                                .font(.title) // 아이콘 크기
                                .foregroundColor(.gray) // 아이콘 색상
                        }
                        .buttonStyle(.plain) // 모든 기본 스타일 제거
                    }
                }

                // --- 기존 데이터 UI (변경 없음) ---
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("거리")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(String(format: "%.2f", context.state.kilometers)) km")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }

                    VStack(alignment: .leading) {
                        Text("페이스")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(String(format: "%.1f", context.state.pace))'/km")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }

                    VStack(alignment: .leading) {
                        Text("시간")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(formatTimeFull(context.state.seconds))")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                }

                if context.state.calories > 0 {
                    Text("🔥 \(String(format: "%.0f", context.state.calories)) kcal")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }

            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(8)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // --- Expanded UI ---
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("거리")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(String(format: "%.2f", context.state.kilometers)) km")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("페이스")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(String(format: "%.1f", context.state.pace))'/km")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(formatTimeFull(context.state.seconds))")
                            .font(.caption2)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if context.state.calories > 0 {
                            Image(systemName: "flame")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(String(format: "%.0f", context.state.calories)) kcal")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()


                        if context.state.isPaused {
                            Button(intent: ResumeRunningIntent()) {
                                Image(systemName: "play.fill")
                                    .font(.title3)
                                    .padding(8)
                                    .background(Color.green)
                                    .foregroundColor(.black)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(intent: PauseRunningIntent()) {
                                Image(systemName: "pause.fill")
                                    .font(.title3)
                                    .padding(8)
                                    .background(Color.orange)
                                    .foregroundColor(.black)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            // --- Compact / Minimal UI ---
            compactLeading: {
                Image(systemName: "figure.run")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text("\(String(format: "%.1f", context.state.pace))")
                    .foregroundColor(.white)
            } minimal: {
                Text("🏃")
                    .foregroundColor(.white)
            }
        }
    }
}
