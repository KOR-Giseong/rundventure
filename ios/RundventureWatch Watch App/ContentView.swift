// ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var connector = WatchConnector()

    @State private var showFreeRunConfirm = false
    @State private var showGhostRunConfirm = false
    
    // ▼▼▼▼▼ [ ✅ 핵심 수정: '폰에서 시작' 안내창 변수 ] ▼▼▼▼▼
    @State private var showStartOnPhoneAlert = false
    // ▲▲▲▲▲ [ ✅ 핵심 수정 ] ▲▲▲▲▲

    var body: some View {
        if connector.isEnded {
            // (파트 2에서 수정할 SummaryView)
            SummaryView(connector: connector)
            
        } else if connector.isRunning {
            // 'runType'에 따라 적절한 러닝 뷰를 표시
            // (이 로직은 폰에서 러닝을 시작했을 때 runType을 수신하여 동작함)
            switch connector.runType {
            
            // ▼▼▼▼▼ [ ✅ 신규 추가: 'friendRace', 'asyncRace' 라우팅 ] ▼▼▼▼▼
            case "friendRace":
                // (파트 2에서 생성할 실시간 대결 뷰)
                FriendBattleWatchView(connector: connector)
            case "asyncRace":
                // (파트 2에서 생성할 오프라인 대결 뷰)
                AsyncBattleWatchView(connector: connector)
            // ▲▲▲▲▲ [ ✅ 신규 추가 ] ▲▲▲▲▲
                
            default:
                // "freeRun", "ghostRecord", "ghostRace"는 기존 뷰 사용
                RunningView(connector: connector)
            }
            
        } else if connector.isCountingDown {
            CountdownView(text: connector.countdownValue)
            
        } else {
            // ▼▼▼▼▼ [ ✅ 핵심 수정: 버튼 4개 표시 및 동작 변경 ] ▼▼▼▼▼
            NavigationView {
                List {
                    // 1. "자유 러닝" 버튼 (기존 동작: Watch -> Phone)
                    Button(action: {
                        if connector.isPhoneReachable() {
                            showFreeRunConfirm = true
                        } else {
                            connector.showNotReachableAlert = true
                        }
                    }) {
                        FeatureRow(
                            iconName: "figure.run",
                            iconColor: .cyan,
                            title: "자유 러닝",
                            subtitle: "혼자서 자유롭게 달리기"
                        )
                    }

                    // 2. "고스트 런" 버튼 (기존 동작: Watch -> Phone)
                    Button(action: {
                        if connector.isPhoneReachable() {
                            showGhostRunConfirm = true
                        } else {
                            connector.showNotReachableAlert = true
                        }
                    }) {
                        FeatureRow(
                            iconName: "ghostlogo", // 에셋 이미지
                            iconColor: .purple,
                            title: "고스트 런",
                            subtitle: "나만의 고스트와 경쟁하기"
                        )
                    }
                    
                    // 3. "실시간 친구 대결" 버튼 (신규 동작: 안내창)
                    Button(action: {
                        // 폰 연결 여부만 확인
                        if connector.isPhoneReachable() {
                            // "폰에서 시작하세요" 안내창 표시
                            showStartOnPhoneAlert = true
                        } else {
                            connector.showNotReachableAlert = true
                        }
                    }) {
                        FeatureRow(
                            iconName: "person.2.fill", // 시스템 아이콘
                            iconColor: .blue,
                            title: "실시간 친구 대결",
                            subtitle: "친구와 동시에 달리기"
                        )
                    }
                    
                    // 4. "오프라인 친구 대결" 버튼 (신규 동작: 안내창)
                    Button(action: {
                        // 폰 연결 여부만 확인
                        if connector.isPhoneReachable() {
                            // "폰에서 시작하세요" 안내창 표시
                            showStartOnPhoneAlert = true
                        } else {
                            connector.showNotReachableAlert = true
                        }
                    }) {
                        FeatureRow(
                            iconName: "person.icloud.fill", // 시스템 아이콘
                            iconColor: .orange,
                            title: "오프라인 친구 대결",
                            subtitle: "친구의 기록에 도전하기"
                        )
                    }

                } // List End
                .listStyle(.carousel)
                .navigationTitle("런드벤처")
                // --- .alert 들 (수정) ---
                .alert("iPhone 연결 필요", isPresented: $connector.showNotReachableAlert) {
                    Button("확인", role: .cancel) { }
                } message: {
                    Text("러닝을 시작하려면 iPhone에서 Rundventure 앱을 실행하고 로그인해주세요.")
                }
                .alert("자유 러닝", isPresented: $showFreeRunConfirm) {
                    Button("아니오", role: .cancel) { }
                    Button("예") {
                        connector.sendStartCommandToPhone() // 👈 명령 전송
                    }
                } message: {
                    Text("자유 러닝을 시작할까요?\n\n로그인 후 iPhone 앱을 메인 화면에 두세요.")
                }
                .alert("고스트 런", isPresented: $showGhostRunConfirm) {
                    Button("아니오", role: .cancel) { }
                    Button("예") {
                        connector.sendStartGhostRunCommandToPhone() // 👈 명령 전송
                    }
                } message: {
                    Text("고스트 런을 시작할까요?\n\n로그인 후 iPhone 앱을 메인 화면에 두세요.")
                }
                
                // ▼▼▼▼▼ [ ✅ 신규 추가: '폰에서 시작' 안내창 ] ▼▼▼▼▼
                .alert("iPhone에서 시작", isPresented: $showStartOnPhoneAlert) {
                    Button("확인", role: .cancel) { }
                } message: {
                    Text("친구 대결은 iPhone 앱에서만 시작할 수 있습니다.\n\n앱을 열고 '실시간 대결' 또는 '오프라인 대결'을 선택해주세요.")
                }
                // ▲▲▲▲▲ [ ✅ 신규 추가 ] ▲▲▲▲▲
                
                .alert("로그인 필요", isPresented: $connector.showLoginRequiredAlert) {
                    Button("확인", role: .cancel) { }
                } message: {
                    Text("iPhone에서 Rundventure 앱을 실행하여 로그인해주세요.")
                }
            } // NavigationView End
            // ▲▲▲▲▲ [ ✅ 핵심 수정 ] ▲▲▲▲▲
        } // else End
    } // body End
} // ContentView End


// --- 헬퍼 뷰 (FeatureRow) ---
struct FeatureRow: View {
    var iconName: String
    var iconColor: Color
    var title: String
    var subtitle: String
    
    // ▼▼▼▼▼ [ ✅ 핵심 수정: 시스템 아이콘/에셋 분기 로직 ] ▼▼▼▼▼
    // "ghostlogo"를 제외한 모든 아이콘을 시스템 아이콘(SF Symbol)으로 간주합니다.
    private var isSystemIcon: Bool {
        return iconName != "ghostlogo"
    }
    // ▲▲▲▲▲ [ ✅ 핵심 수정 ] ▲▲▲▲▲

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.3))
                    .frame(width: 40, height: 40)

                // ▼▼▼▼▼ [ ✅ 핵심 수정: 아이콘 생성 로직 ] ▼▼▼▼▼
                if isSystemIcon {
                    Image(systemName: iconName) // "figure.run", "person.2.fill" 등
                        .foregroundColor(iconColor)
                        .font(.headline)
                } else {
                    Image(iconName) // "ghostlogo"
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(iconColor)
                }
                // ▲▲▲▲▲ [ ✅ 핵심 수정 ] ▲▲▲▲▲
            }

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}
