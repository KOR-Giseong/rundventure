import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct GhostRaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GhostRaceActivityAttributes.self) { context in
            ZStack {
                Color.black.opacity(0.9)

                VStack(spacing: 15) {

                    HStack {
                        Image("ghostlogo")
                            .resizable().frame(width: 20, height: 20)
                        Text("고스트와 대결 중!")
                            .font(.headline).fontWeight(.bold).foregroundColor(.white)
                        
                        Spacer() // 중간을 밀어냄

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

                    
                }
                .padding(20)
            }

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
