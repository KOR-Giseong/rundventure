import UIKit
import Flutter
import GoogleSignIn
import Firebase
import UserNotifications
import AuthenticationServices
import CoreLocation
import ActivityKit
import CoreMotion

import watch_connectivity

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {

    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var locationManager = CLLocationManager()
    let motionManager = CMMotionActivityManager()

    // --- 기존 액티비티 ---
    var mainRunActivity: Activity<RunningLiveActivityAttributes>? = nil
    var ghostRecordActivity: Activity<GhostRunActivityAttributes>? = nil
    var ghostRaceActivity: Activity<GhostRaceActivityAttributes>? = nil
    
    // 대결용 액티비티
    var asyncBattleActivity: Activity<AsyncBattleActivityAttributes>? = nil
    var friendBattleActivity: Activity<FriendBattleActivityAttributes>? = nil
    
    var liveActivityChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        GeneratedPluginRegistrant.register(with: self) // 플러그인 등록
        
        // App Intent가 보낸 알림을 여기서 듣습니다.
        self.setupDarwinNotificationListeners()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()

        requestNotificationAuthorization()
        requestMotionAuthorization()
        
        if let controller = window?.rootViewController as? FlutterViewController {
            self.liveActivityChannel = FlutterMethodChannel(
                name: "com.rundventure/liveactivity",
                binaryMessenger: controller.binaryMessenger
            )
            
            self.liveActivityChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
                
                guard let args = call.arguments as? [String: Any], let type = args["type"] as? String else {
                    result(FlutterMethodNotImplemented)
                    return
                }

                switch call.method {
                case "startLiveActivity":
                    self?.startLiveActivity(type: type, data: args)
                    result(nil)
                case "updateLiveActivity":
                    self?.updateLiveActivity(type: type, data: args)
                    result(nil)
                case "stopLiveActivity":
                    self?.stopLiveActivity(type: type)
                    result(nil)
                // ⚠️ Native -> Flutter 호출을 위한 핸들러는 Dart에서 설정
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // C 포인터 오류 해결
    private func setupDarwinNotificationListeners() {
        // 'self'를 C 포인터로 변환
        let observer = Unmanaged.passUnretained(self).toOpaque()

        // "일시정지" 알림 수신 설정
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer, // 'self'의 포인터를 전달
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                
                // 전달받은 포인터를 다시 AppDelegate 인스턴스로 복원
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                
                print("🏃‍♂️ [AppDelegate] 'pause' 알림 수신! Flutter로 전달합니다.")
                
                // 복원된 인스턴스를 통해 함수 호출
                appDelegate.sendRunningCommandToFlutter("pauseRunning")
            },
            "com.rundventure.pause" as CFString,
            nil,
            .deliverImmediately
        )
        
        // "재개" 알림 수신 설정
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer, // 'self'의 포인터를 전달
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }

                // 전달받은 포인터를 다시 AppDelegate 인스턴스로 복원
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()

                print("🏃‍♂️ [AppDelegate] 'resume' 알림 수신! Flutter로 전달합니다.")
                
                // 복원된 인스턴스를 통해 함수 호출
                appDelegate.sendRunningCommandToFlutter("resumeRunning")
            },
            "com.rundventure.resume" as CFString,
            nil,
            .deliverImmediately
        )
    }
    
    // Flutter로 명령을 전송하는 헬퍼
    private func sendRunningCommandToFlutter(_ command: String) {
        let message = ["command": command]
        
        // ⚠️ 'watch_connectivity'가 아니라, 이미 존재하는 'liveActivityChannel'을 사용해
        // Flutter(Dart)의 메소드("handleLiveActivityCommand")를 직접 호출
        self.liveActivityChannel?.invokeMethod("handleLiveActivityCommand", arguments: message) { (result) in
            if let error = result as? FlutterError {
                print("🚨 [AppDelegate] Flutter로 \(command) 전송 실패: \(error.message ?? "")")
            } else {
                print("✅ [AppDelegate] Flutter로 \(command) 명령 전송 성공")
            }
        }
    }


    // startLiveActivity
    func startLiveActivity(type: String, data: [String: Any]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if #available(iOS 16.2, *) {
            if type == "main" {
                Task {
                    for activity in Activity<RunningLiveActivityAttributes>.activities {
                        await activity.end(nil, dismissalPolicy: .immediate)
                        print("✅ Found and ended existing 'main' activity.")
                    }
                    let attributes = RunningLiveActivityAttributes(name: "런드벤처")
                    let initialState = RunningLiveActivityAttributes.ContentState(kilometers: 0.0, seconds: 0, pace: 0.0, calories: 0.0, isPaused: false)
                    let content = ActivityContent(state: initialState, staleDate: nil)
                    do {
                        let activity = try Activity<RunningLiveActivityAttributes>.request(attributes: attributes, content: content)
                        self.mainRunActivity = activity
                        print("✅ Main Run Live Activity Started")
                    } catch { print("❌ Main Run Start Error: \(error.localizedDescription)") }
                }

            } else if type == "ghost_record" {
                Task {
                    for activity in Activity<GhostRunActivityAttributes>.activities {
                        await activity.end(nil, dismissalPolicy: .immediate)
                        print("✅ Found and ended existing 'ghost_record' activity.")
                    }
                    let attributes = GhostRunActivityAttributes()
                    let initialState = GhostRunActivityAttributes.ContentState(time: "00:00", distance: "0.00", pace: "0:00", isPaused: false)
                    let content = ActivityContent(state: initialState, staleDate: nil)
                    do {
                        let activity = try Activity<GhostRunActivityAttributes>.request(attributes: attributes, content: content)
                        self.ghostRecordActivity = activity
                        print("✅ Ghost Record Live Activity Started")
                    } catch { print("❌ Ghost Record Start Error: \(error.localizedDescription)") }
                }

            } else if type == "ghost_race" {
                Task {
                    for activity in Activity<GhostRaceActivityAttributes>.activities {
                        await activity.end(nil, dismissalPolicy: .immediate)
                        print("✅ Found and ended existing 'ghost_race' activity.")
                    }
                    let attributes = GhostRaceActivityAttributes()
                    let initialState = GhostRaceActivityAttributes.ContentState(userTime: "00:00", userDistance: "0.00", userPace: "0:00", raceStatus: "대결 시작!", isPaused: false)
                    let content = ActivityContent(state: initialState, staleDate: nil)
                    do {
                        let activity = try Activity<GhostRaceActivityAttributes>.request(attributes: attributes, content: content)
                        self.ghostRaceActivity = activity
                        print("✅ Ghost Race Live Activity Started")
                    } catch { print("❌ Ghost Race Start Error: \(error.localizedDescription)") }
                }
            
            // 비동기 대결
            } else if type == "async_battle" {
                Task {
                    // 1. 기존 액티비티 종료
                    for activity in Activity<AsyncBattleActivityAttributes>.activities {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                    // 2. 새 액티비티 시작
                    // Dart에서 보낸 targetDistanceKm 값을 attributes에 저장
                    let targetKm = data["targetDistanceKm"] as? Double ?? 0.0
                    let attributes = AsyncBattleActivityAttributes(targetDistanceKm: targetKm)
                    
                    let initialState = AsyncBattleActivityAttributes.ContentState(
                        kilometers: 0.0, seconds: 0, pace: 0.0, calories: 0.0, isPaused: false, isMyRunFinished: false
                    )
                    let content = ActivityContent(state: initialState, staleDate: nil)
                    do {
                        let activity = try Activity<AsyncBattleActivityAttributes>.request(attributes: attributes, content: content)
                        self.asyncBattleActivity = activity
                        print("✅ Async Battle Live Activity Started")
                    } catch { print("❌ Async Battle Start Error: \(error.localizedDescription)") }
                }
            }
            
            // 실시간 친구 대결
            else if type == "friend_battle" {
                Task {
                    // 1. 기존 액티비티 종료
                    for activity in Activity<FriendBattleActivityAttributes>.activities {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                    // 2. 새 액티비티 시작
                    // Dart에서 보낸 targetDistanceKm 값을 attributes에 저장
                    let targetKm = data["targetDistanceKm"] as? Double ?? 0.0
                    let attributes = FriendBattleActivityAttributes(targetDistanceKm: targetKm)
                    
                    // Dart에서 보낸 초기 닉네임 사용
                    let initialOpponentNickname = data["opponentNickname"] as? String ?? "상대방"
                    
                    let initialState = FriendBattleActivityAttributes.ContentState(
                        myKilometers: 0.0,
                        mySeconds: 0,
                        myPace: 0.0,
                        isMyRunFinished: false,
                        opponentNickname: initialOpponentNickname,
                        opponentDistance: 0.0,
                        isOpponentFinished: false
                    )
                    let content = ActivityContent(state: initialState, staleDate: nil)
                    do {
                        let activity = try Activity<FriendBattleActivityAttributes>.request(attributes: attributes, content: content)
                        self.friendBattleActivity = activity
                        print("✅ Friend Battle Live Activity Started")
                    } catch { print("❌ Friend Battle Start Error: \(error.localizedDescription)") }
                }
            }
            
        }
    }

    func updateLiveActivity(type: String, data: [String: Any]) {
        Task {
            if #available(iOS 16.2, *) {
                if type == "main" {
                    if let km = data["kilometers"] as? Double, let sec = data["seconds"] as? Int, let pace = data["pace"] as? Double, let cal = data["calories"] as? Double, let isPaused = data["isPaused"] as? Bool {
                        let state = RunningLiveActivityAttributes.ContentState(kilometers: km, seconds: sec, pace: pace, calories: cal, isPaused: isPaused)
                        let content = ActivityContent(state: state, staleDate: nil)
                        await self.mainRunActivity?.update(content)
                    }
                } else if type == "ghost_record" {
                    if let time = data["time"] as? String, let dist = data["distance"] as? String, let pace = data["pace"] as? String, let isPaused = data["isPaused"] as? Bool {
                        let state = GhostRunActivityAttributes.ContentState(time: time, distance: dist, pace: pace, isPaused: isPaused)
                        let content = ActivityContent(state: state, staleDate: nil)
                        await self.ghostRecordActivity?.update(content)
                    }
                } else if type == "ghost_race" {
                    if let time = data["userTime"] as? String, let dist = data["userDistance"] as? String, let pace = data["userPace"] as? String, let status = data["raceStatus"] as? String, let isPaused = data["isPaused"] as? Bool {
                        let state = GhostRaceActivityAttributes.ContentState(userTime: time, userDistance: dist, userPace: pace, raceStatus: status, isPaused: isPaused)
                        let content = ActivityContent(state: state, staleDate: nil)
                        await self.ghostRaceActivity?.update(content)
                    }
                
                // 비동기 대결
                } else if type == "async_battle" {
                    // (Dart의 _updatePaceAndSpeed 키와 일치시킴)
                    if let km = data["kilometers"] as? Double,
                       let sec = data["seconds"] as? Int,
                       let pace = data["pace"] as? Double,
                       let cal = data["calories"] as? Double,
                       let isPaused = data["isPaused"] as? Bool,
                       let isMyRunFinished = data["isMyRunFinished"] as? Bool {
                        
                        let state = AsyncBattleActivityAttributes.ContentState(
                            kilometers: km, seconds: sec, pace: pace, calories: cal, isPaused: isPaused, isMyRunFinished: isMyRunFinished
                        )
                        let content = ActivityContent(state: state, staleDate: nil)
                        await self.asyncBattleActivity?.update(content)
                    }
                    

                // 실시간 친구 대결
                } else if type == "friend_battle" {
                    if let myKm = data["myKilometers"] as? Double,      // 'myKilometers' 키 사용
                       let mySec = data["mySeconds"] as? Int,          // 'mySeconds' 키 사용
                       let myPace = data["myPace"] as? Double,         // 'myPace' 키 사용
                       let isMyFinished = data["isMyRunFinished"] as? Bool,
                       let oppNick = data["opponentNickname"] as? String,
                       let oppDist = data["opponentDistance"] as? Double,
                       let isOppFinished = data["isOpponentFinished"] as? Bool {
                        
                        let state = FriendBattleActivityAttributes.ContentState(
                            myKilometers: myKm,
                            mySeconds: mySec,
                            myPace: myPace,
                            isMyRunFinished: isMyFinished,
                            opponentNickname: oppNick,
                            opponentDistance: oppDist,
                            isOpponentFinished: isOppFinished
                        )
                        let content = ActivityContent(state: state, staleDate: nil)
                        await self.friendBattleActivity?.update(content)

                        
                    } else {
                         print("🚨 Friend Battle Update FAILED. Data received: \(data)")
                    }
                }
                
            }
        }
    }

    func stopLiveActivity(type: String) {
        Task {
            if #available(iOS 16.1, *) {
                
                if type == "main" {
                    // nil의 타입을 명시적으로 지정
                    let emptyContent: ActivityContent<RunningLiveActivityAttributes.ContentState>? = nil
                    await mainRunActivity?.end(emptyContent, dismissalPolicy: .immediate)
                    self.mainRunActivity = nil
                    print("✅ Main Run Live Activity Stopped")
                    
                } else if type == "ghost_record" {
                    // nil의 타입을 명시적으로 지정
                    let emptyContent: ActivityContent<GhostRunActivityAttributes.ContentState>? = nil
                    await ghostRecordActivity?.end(emptyContent, dismissalPolicy: .immediate)
                    self.ghostRecordActivity = nil
                    print("✅ Ghost Record Live Activity Stopped")
                    
                } else if type == "ghost_race" {
                    // nil의 타입을 명시적으로 지정
                    let emptyContent: ActivityContent<GhostRaceActivityAttributes.ContentState>? = nil
                    await ghostRaceActivity?.end(emptyContent, dismissalPolicy: .immediate)
                    self.ghostRaceActivity = nil
                    print("✅ Ghost Race Live Activity Stopped")

                } else if type == "async_battle" {
                    // nil의 타입을 명시적으로 지정
                    let emptyContent: ActivityContent<AsyncBattleActivityAttributes.ContentState>? = nil
                    await asyncBattleActivity?.end(emptyContent, dismissalPolicy: .immediate)
                    self.asyncBattleActivity = nil
                    print("✅ Async Battle Live Activity Stopped")

                } else if type == "friend_battle" {
                    // nil의 타입을 명시적으로 지정
                    let emptyContent: ActivityContent<FriendBattleActivityAttributes.ContentState>? = nil
                    await friendBattleActivity?.end(emptyContent, dismissalPolicy: .immediate)
                    self.friendBattleActivity = nil
                    print("✅ Friend Battle Live Activity Stopped")
                }
            }
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 알림 권한 허용됨")
            } else {
                print("❌ 알림 권한 거부됨: \(error?.localizedDescription ?? "")")
            }
        }
    }

    private func requestMotionAuthorization() {
        if CMMotionActivityManager.isActivityAvailable() {
            motionManager.queryActivityStarting(from: Date(), to: Date(), to: OperationQueue.main) { activities, error in
                if let error = error {
                    print("❌ Motion 권한 거부됨: \(error.localizedDescription)")
                } else {
                    print("✅ Motion 권헌 허용됨")
                }
            }
        }
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundTask = application.beginBackgroundTask(withName: "LocationTracking") {
            application.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // ✅ GIDSignIn 괄호 오류 수정
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        if #available(iOS 13.0, *) {
            if let scheme = url.scheme, scheme.contains("com.rundventure.login") {
                return true
            }
        }
        return super.application(app, open: url, options: options)
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            print("위치 권한 허용됨")
        case .denied, .restricted:
            print("위치 권한 거부됨")
        default:
            break
        }
    }
}
