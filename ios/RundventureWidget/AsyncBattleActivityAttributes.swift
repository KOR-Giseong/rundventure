//
//  AsyncBattleActivityAttributes.swift
//  RundventureWidgetExtension
//
//  Created by (Your Name) on (Current Date).
//

import ActivityKit
import Foundation

// '비동기 대결' (오프라인 대결)을 위한 속성 정의
struct AsyncBattleActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        // 'async_battle_running_screen.dart'의 _updatePaceAndSpeed에서 보낸 데이터
        var kilometers: Double
        var seconds: Int
        var pace: Double
        var calories: Double
        var isPaused: Bool
        
        // 'async_battle_running_screen.dart'의 _finishMyRun에서 보낸 데이터
        var isMyRunFinished: Bool
    }

    // --- 정적 데이터 ---
    var appName: String = "Rundventure"
    
    // ⭐️ [신규 추가] 목표 거리 (시작 시 한 번만 설정)
    var targetDistanceKm: Double
}
