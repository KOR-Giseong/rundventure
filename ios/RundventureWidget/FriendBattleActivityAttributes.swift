//
//  FriendBattleActivityAttributes.swift
//  RundventureWidgetExtension
//
//  Created by (Your Name) on (Current Date).
//

import ActivityKit
import Foundation

// '실시간 친구 대결'을 위한 속성 정의
struct FriendBattleActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        // 'friend_battle_running_screen.dart'의 _updatePaceAndSpeed에서 보낸 데이터

        // 나의 데이터
        var myKilometers: Double
        var mySeconds: Int
        var myPace: Double
        var isMyRunFinished: Bool // 내가 완주했는지
        
        // 상대방 데이터
        var opponentNickname: String
        var opponentDistance: Double
        var isOpponentFinished: Bool // 상대가 완주했는지
    }

    // --- 정적 데이터 ---
    var appName: String = "Rundventure"
    
    // ⭐️ [신규 추가] 목표 거리 (시작 시 한 번만 설정)
    // 이 값은 변하지 않으므로 ContentState가 아닌 여기에 둡니다.
    var targetDistanceKm: Double
}
