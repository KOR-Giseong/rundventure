import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct GhostRunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GhostRunActivityAttributes.self) { context in
            ZStack {
                Color.black.opacity(0.9)
                
                // MARK: 잠금화면 UI (고스트 첫 기록 측정 디자인)
                VStack(alignment: .center, spacing: 15) { // 중앙 정렬 및 간격 조정
                    
                    // 상단 HStack: 로고 + Spacer + 버튼
                    HStack(alignment: .center, spacing: 8) { // 아이콘과 텍스트 중앙 정렬
                        Image(systemName: "figure.walk.motion") // 기록 측정에 어울리는 아이콘
                            .font(.title2)
                            .foregroundColor(.purple) // 고스트 테마에 어울리는 색상
                        Text("고스트 러닝")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
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
                    .padding(.bottom, 5)

                    // 주요 데이터 강조
                    HStack(spacing: 30) {
                        VStack { // 시간
                            Text("시간").font(.caption).foregroundColor(.white.opacity(0.8))
                            Text(context.state.time)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        VStack { // 거리
                            Text("거리").font(.caption).foregroundColor(.white.opacity(0.8))
                            Text("\(context.state.distance) km")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        VStack { // 페이스
                            Text("페이스").font(.caption).foregroundColor(.white.opacity(0.8))
                            Text(context.state.pace)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 10)


                    
                }
                .padding(20)
            }
            
        } dynamicIsland: { context in
            DynamicIsland {
                // (다이나믹 아일랜드 부분은 수정할 필요 없습니다)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("거리").font(.caption2).foregroundColor(.white.opacity(0.6))
                        Text("\(context.state.distance) km").font(.subheadline).fontWeight(.semibold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("페이스").font(.caption2).foregroundColor(.white.opacity(0.6))
                        Text(context.state.pace).font(.subheadline).fontWeight(.semibold)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "hourglass") // 모래시계 아이콘
                            .foregroundColor(.purple)
                        Text(context.state.time)
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
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))
                }
            }
            compactLeading: {
                Image(systemName: "figure.walk.motion")
                    .foregroundColor(.purple)
            }
            compactTrailing: {
                Text(context.state.pace).font(.caption).fontWeight(.medium).foregroundColor(.white)
            }
            minimal: {
                Image(systemName: "hourglass")
                    .foregroundColor(.purple)
            }
            .widgetURL(URL(string: "http://www.rundventure.com/ghostrun"))
            .keylineTint(Color.purple.opacity(0.8))
        }
    }
}
