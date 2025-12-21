import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents // ✅ [추가] AppIntents 임포트

struct GhostRaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GhostRaceActivityAttributes.self) { context in
            // ✅ [수정] ZStack을 사용해 배경을 직접 설정
            ZStack {
                // 배경색을 가장 아래에 깔아줍니다.
                Color.black.opacity(0.9)

                // 기존 UI 콘텐츠는 ZStack 위에 그대로 올립니다.
                VStack(spacing: 15) {
                    
                    // ✅ [수정] 상단 HStack: 로고 + Spacer + 버튼
                    HStack {
                        Image("ghostlogo")
                            .resizable().frame(width: 20, height: 20)
                        Text("고스트와 대결 중!")
                            .font(.headline).fontWeight(.bold).foregroundColor(.white)
                        
                        Spacer() // 중간을 밀어냄
                        
                        // ✅ [수정] 우측 상단 아이콘 버튼 (배경 없음)
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
                    
                    // '나'의 기록
                    HStack(spacing: 20) {
                        Text("Me").font(.callout).fontWeight(.bold).foregroundColor(.cyan).frame(width: 50)
                        Text(context.state.userTime).frame(maxWidth: .infinity)
                        Text(context.state.userDistance + " km").frame(maxWidth: .infinity)
                        Text(context.state.userPace).frame(maxWidth: .infinity)
                    }.foregroundColor(.white)

                    // '고스트'와의 상태
                    HStack {
                        Text("Ghost").font(.callout).fontWeight(.bold).foregroundColor(.purple).frame(width: 50)
                        Text(context.state.raceStatus)
                            .font(.subheadline).fontWeight(.medium).foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // ✅ [삭제] 기존의 하단 버튼 HStack은 삭제됨
                    
                }
                .padding(20)
            }
            // ✅ .background와 .widgetBackground modifier는 제거합니다.

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Me").font(.caption)
                    Text(context.state.userPace).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack {
                        Image("ghostlogo").resizable().frame(width: 20, height: 20)
                        Text(context.state.raceStatus).font(.headline)
                    }
                }
                // ✅ [수정] 다이나믹 아일랜드 Expanded 하단 버튼: Link -> Button(intent: ...)
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        Text("Me: \(context.state.userTime)")
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
                        Spacer()
                    }
                    .font(.footnote)
                }
            }
            compactLeading: {
                Image(systemName: "figure.run").foregroundColor(.cyan)
            }
            compactTrailing: {
                HStack(spacing: 4) {
                    Image("ghostlogo").resizable().frame(width: 15, height: 15)
                    Text(context.state.raceStatus).font(.caption)
                }
            }
            minimal: {
                Image("ghostlogo")
            }
        }
    }
}
