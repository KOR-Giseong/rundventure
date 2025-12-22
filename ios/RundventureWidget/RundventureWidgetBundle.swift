import WidgetKit
import SwiftUI

@main
struct RundventureWidgetBundle: WidgetBundle {
    var body: some Widget {
        // --- 기존 라이브 액티비티 ---
        
        // 1. 자유 러닝 (RunningPage)
        RundventureWidgetLiveActivity()
        
        // 2. 고스트런 (첫 기록)
        GhostRunLiveActivity()
        
        // 3. 고스트런 (대결)
        GhostRaceLiveActivity()

        
        // 4. 비동기/오프라인 대결 (AsyncBattleRunningScreen)
        AsyncBattleLiveActivity()
        
        // 5. 실시간 친구 대결 (FriendBattleRunningScreen)
        FriendBattleLiveActivity()
        

        // RundventureWidget()
    }
}
