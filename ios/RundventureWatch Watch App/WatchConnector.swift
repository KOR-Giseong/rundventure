// [전체 코드] WatchConnector.swift

import Foundation
import WatchConnectivity
import SwiftUI

class WatchConnector: NSObject, WCSessionDelegate, ObservableObject {
    
    // --- Published 변수들 ---
    @Published var kilometers: Double = 0.0
    @Published var seconds: Int = 0
    @Published var milliseconds: Int = 0 // 👈 폰에서 받은 밀리초 (0~999)

    @Published var pace: Double = 0.0
    @Published var calories: Double = 0.0
    
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var isEnded: Bool = false
    @Published var showNotReachableAlert = false // 폰 연결 불가 알림
    
    @Published var isCountingDown: Bool = false
    @Published var countdownValue: String = ""
    
    @Published var runType: String = "freeRun"
    @Published var raceStatus: String = "" // 고스트런 대결 상태 메시지
    @Published var raceOutcome: String = "" // 고스트런/친구 대결 결과 ("win", "lose", "tie", "draw")
    
    // 친구/오프라인 대결 변수
    @Published var opponentNickname: String = "상대방"
    @Published var opponentKilometers: Double = 0.0
    @Published var targetDistanceKm: Double = 0.0
    
    // 로그인 필요 알림
    @Published var showLoginRequiredAlert = false
    
    private var session: WCSession

    // 초기화 함수
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        self.session.delegate = self
        self.session.activate()
        
        // 앱 시작 시 마지막 Application Context 상태 복원
        let receivedContext = session.receivedApplicationContext
        if !receivedContext.isEmpty {
            print("✅ Watch launched. Checking initial context: \(receivedContext)")
            if let isRunning = receivedContext["isRunning"] as? Bool, isRunning == true {
                DispatchQueue.main.async {
                    self.isRunning = true
                    self.isEnded = false
                    if let runType = receivedContext["runType"] as? String { self.runType = runType }
                    if let outcome = receivedContext["raceOutcome"] as? String { self.raceOutcome = outcome }
                    if let ended = receivedContext["isEnded"] as? Bool {
                        self.isEnded = ended
                        if ended { self.isRunning = false }
                    }
                    if let km = receivedContext["kilometers"] as? Double { self.kilometers = km }
                    if let sec = receivedContext["seconds"] as? Int { self.seconds = sec }
                    // ▼▼▼▼▼ [ ⭐️ 밀리초 복원 ⭐️ ] ▼▼▼▼▼
                    if let ms = receivedContext["milliseconds"] as? Int { self.milliseconds = ms }
                    // ▲▲▲▲▲ [ ⭐️ 밀리초 복원 ⭐️ ] ▲▲▲▲▲
                    
                    if let pc = receivedContext["pace"] as? Double { self.pace = pc }
                    if let cal = receivedContext["calories"] as? Double { self.calories = cal }
                    if let status = receivedContext["raceStatus"] as? String { self.raceStatus = status }
                    
                    if let oppNick = receivedContext["opponentNickname"] as? String { self.opponentNickname = oppNick }
                    if let oppKm = receivedContext["opponentDistance"] as? Double { self.opponentKilometers = oppKm }
                    if let targetKm = receivedContext["targetDistanceKm"] as? Double { self.targetDistanceKm = targetKm }
                }
            } else {
                DispatchQueue.main.async {
                    if receivedContext["isEnded"] as? Bool != true {
                        self.resetState()
                    } else {
                        self.isEnded = true
                        self.isRunning = false
                        if let runType = receivedContext["runType"] as? String { self.runType = runType }
                        if let outcome = receivedContext["raceOutcome"] as? String { self.raceOutcome = outcome }
                        if let km = receivedContext["kilometers"] as? Double { self.kilometers = km }
                        if let sec = receivedContext["seconds"] as? Int { self.seconds = sec }
                        // ▼▼▼▼▼ [ ⭐️ 밀리초 복원 ⭐️ ] ▼▼▼▼▼
                        if let ms = receivedContext["milliseconds"] as? Int { self.milliseconds = ms }
                        // ▲▲▲▲▲ [ ⭐️ 밀리초 복원 ⭐️ ] ▲▲▲▲▲
                        
                        if let pc = receivedContext["pace"] as? Double { self.pace = pc }
                        if let cal = receivedContext["calories"] as? Double { self.calories = cal }
                        
                        if let oppNick = receivedContext["opponentNickname"] as? String { self.opponentNickname = oppNick }
                        if let oppKm = receivedContext["opponentDistance"] as? Double { self.opponentKilometers = oppKm }
                        if let targetKm = receivedContext["targetDistanceKm"] as? Double { self.targetDistanceKm = targetKm }
                    }
                }
            }
        }
    }

    // --- WCSessionDelegate 메소드 ---
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        self.handleReceivedMessage(message)
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        self.handleReceivedMessage(applicationContext)
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activation completed with state: \(activationState.rawValue)")
        if activationState == .activated {
            let receivedContext = session.receivedApplicationContext
            if !receivedContext.isEmpty {
                // (재활성화 시에도 위 init과 동일하게 상태 복원 로직 수행)
                if let isRunning = receivedContext["isRunning"] as? Bool, isRunning == true {
                    DispatchQueue.main.async {
                        self.isRunning = true
                        self.isEnded = false
                        if let runType = receivedContext["runType"] as? String { self.runType = runType }
                        if let outcome = receivedContext["raceOutcome"] as? String { self.raceOutcome = outcome }
                        if let ended = receivedContext["isEnded"] as? Bool {
                            self.isEnded = ended
                            if ended { self.isRunning = false }
                        }
                        if let km = receivedContext["kilometers"] as? Double { self.kilometers = km }
                        if let sec = receivedContext["seconds"] as? Int { self.seconds = sec }
                        if let ms = receivedContext["milliseconds"] as? Int { self.milliseconds = ms } // 👈
                        
                        if let pc = receivedContext["pace"] as? Double { self.pace = pc }
                        if let cal = receivedContext["calories"] as? Double { self.calories = cal }
                        if let status = receivedContext["raceStatus"] as? String { self.raceStatus = status }

                        if let oppNick = receivedContext["opponentNickname"] as? String { self.opponentNickname = oppNick }
                        if let oppKm = receivedContext["opponentDistance"] as? Double { self.opponentKilometers = oppKm }
                        if let targetKm = receivedContext["targetDistanceKm"] as? Double { self.targetDistanceKm = targetKm }
                    }
                } else {
                    DispatchQueue.main.async {
                        if receivedContext["isEnded"] as? Bool != true {
                            self.resetState()
                        } else {
                            self.isEnded = true
                            self.isRunning = false
                            if let runType = receivedContext["runType"] as? String { self.runType = runType }
                            if let outcome = receivedContext["raceOutcome"] as? String { self.raceOutcome = outcome }
                            if let km = receivedContext["kilometers"] as? Double { self.kilometers = km }
                            if let sec = receivedContext["seconds"] as? Int { self.seconds = sec }
                            if let ms = receivedContext["milliseconds"] as? Int { self.milliseconds = ms } // 👈
                            
                            if let pc = receivedContext["pace"] as? Double { self.pace = pc }
                            if let cal = receivedContext["calories"] as? Double { self.calories = cal }

                            if let oppNick = receivedContext["opponentNickname"] as? String { self.opponentNickname = oppNick }
                            if let oppKm = receivedContext["opponentDistance"] as? Double { self.opponentKilometers = oppKm }
                            if let targetKm = receivedContext["targetDistanceKm"] as? Double { self.targetDistanceKm = targetKm }
                        }
                    }
                }
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
    
    // --- 메시지/Context 공통 처리 핸들러 ---
    private func handleReceivedMessage(_ message: [String: Any]) {
        DispatchQueue.main.async {
            
            if let errorType = message["error"] as? String, errorType == "loginRequired" {
                print("⚠️ Watch received 'loginRequired' error from Phone.")
                self.showLoginRequiredAlert = true
                self.isCountingDown = false
                self.isRunning = false
                return
            }

            // 데이터 수신
            if let type = message["type"] as? String, (type == "main" || type == "battle") {
                self.kilometers = message["kilometers"] as? Double ?? self.kilometers
                self.seconds = message["seconds"] as? Int ?? self.seconds
                // 폰에서 보내주면 저장, 안 보내주면 기존 값 유지
                self.milliseconds = message["milliseconds"] as? Int ?? self.milliseconds
                
                self.pace = message["pace"] as? Double ?? self.pace
                self.calories = message["calories"] as? Double ?? self.calories
                self.raceStatus = message["raceStatus"] as? String ?? ""
                self.opponentKilometers = message["opponentDistance"] as? Double ?? self.opponentKilometers
            }
            
            if let runType = message["runType"] as? String {
                self.runType = runType
            }
            
            if let outcome = message["raceOutcome"] as? String {
                self.raceOutcome = outcome
            }
            
            if let oppNick = message["opponentNickname"] as? String {
                self.opponentNickname = oppNick
            }
            if let targetKm = message["targetDistanceKm"] as? Double {
                self.targetDistanceKm = targetKm
            }

            // 명령 수신
            if let command = message["command"] as? String {
                print("✅ Watch received command from Phone: \(command)")
                switch command {
                case "showWarmup":
                    self.isCountingDown = true; self.countdownValue = "준비"
                case "countdown":
                    self.isCountingDown = true
                    if let value = message["value"] as? Int { self.countdownValue = String(value) }
                case "startRunningUI":
                    self.isCountingDown = true; self.countdownValue = "시작!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isCountingDown = false; self.isRunning = true
                    }
                case "startFromPhone":
                    self.isRunning = true; self.isEnded = false; self.isPaused = false
                case "pauseFromPhone":
                    self.isPaused = true
                case "resumeFromPhone":
                    self.isPaused = false
                case "stopFromPhone":
                    print("✅ Run finished by phone.")
                    self.kilometers = message["kilometers"] as? Double ?? self.kilometers
                    self.seconds = message["seconds"] as? Int ?? self.seconds
                    self.milliseconds = message["milliseconds"] as? Int ?? self.milliseconds
                    
                    self.pace = message["pace"] as? Double ?? self.pace
                    self.calories = message["calories"] as? Double ?? self.calories
                    self.raceOutcome = message["raceOutcome"] as? String ?? ""
                    
                    self.opponentKilometers = message["opponentDistance"] as? Double ?? self.opponentKilometers
                    self.targetDistanceKm = message["targetDistanceKm"] as? Double ?? self.targetDistanceKm

                    self.isEnded = true
                    self.isRunning = false
                case "resetToMainMenu":
                    self.resetState()
                default:
                    break
                }
            }
            
            // 상태 동기화
            if let isRunning = message["isRunning"] as? Bool {
                if message["command"] == nil {
                    self.isPaused = message["isPaused"] as? Bool ?? self.isPaused
                }
                self.isRunning = isRunning
                if !isRunning {
                    if !self.isEnded {
                        self.resetState()
                    }
                } else {
                    self.isEnded = false
                }
            }
            if let isEnded = message["isEnded"] as? Bool {
                self.isEnded = isEnded
                if isEnded { self.isRunning = false }
            }
        }
    }

    // --- 헬퍼 함수 (폰 연결 확인) ---
    public func isPhoneReachable() -> Bool {
        return self.session.isReachable
    }

    // --- 폰으로 메시지 전송 ---
    private func sendCommandToPhoneViaMessage(_ command: String) {
        guard session.isReachable else {
            DispatchQueue.main.async {
                self.showNotReachableAlert = true
            }
            return
        }
        
        let message = ["command": command]
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to send message command \(command): \(error.localizedDescription)")
        }
    }
    
    // --- 워치 -> 폰 명령 ---
    func sendStartCommandToPhone() { sendCommandToPhoneViaMessage("startRunningFromWatch") }
    func sendStartGhostRunCommandToPhone() { sendCommandToPhoneViaMessage("startGhostRunFromWatch") }
    func sendPauseCommandToPhone() { sendCommandToPhoneViaMessage("pauseRunning") }
    func sendResumeCommandToPhone() { sendCommandToPhoneViaMessage("resumeRunning") }
    func sendStopCommandToPhone() { sendCommandToPhoneViaMessage("stopRunning") }
    func sendSaveCommandToPhone() { sendCommandToPhoneViaMessage("saveRunning"); self.resetState() }
    func sendCancelCommandToPhone() { sendCommandToPhoneViaMessage("cancelRunning"); self.resetState() }
    func sendShowHistoryCommand() { sendCommandToPhoneViaMessage("showHistory") }
    func sendResetCommand() { sendCommandToPhoneViaMessage("resetToMainMenu"); self.resetState() }
    
    // --- 상태 초기화 함수 (수정) ---
    func resetState() {
        DispatchQueue.main.async {
            self.kilometers = 0.0; self.seconds = 0; self.pace = 0.0; self.calories = 0.0
            self.milliseconds = 0
            
            self.isRunning = false; self.isPaused = false; self.isEnded = false
            self.isCountingDown = false
            self.runType = "freeRun"
            self.raceStatus = ""
            self.raceOutcome = ""
            
            self.opponentNickname = "상대방"
            self.opponentKilometers = 0.0
            self.targetDistanceKm = 0.0
            
            self.showLoginRequiredAlert = false
            self.showNotReachableAlert = false
        }
    }
}
