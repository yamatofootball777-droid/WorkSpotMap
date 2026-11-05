import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var status = "位置情報は任意です。許可しなくても駅名で検索できます。"
    @Published private(set) var consent: Bool
    @Published private(set) var locating = false
    @Published private(set) var denied = false
    let history = VisitHistory()
    // Created on MainActor: Core Location delivers delegate callbacks on this run loop.
    private let manager = CLLocationManager()
    private let consentKey = "experimental_surroundings_consent_v2"
    private var active = false
    private var requested = false
    private var spots: [Spot] = []

    override init() {
        consent = UserDefaults.standard.bool(forKey: consentKey)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    func setActive(_ value: Bool, spots: [Spot]) {
        active = value
        self.spots = spots
        if !value {
            requested = false
            location = nil
            history.interrupt(reason: "画面非表示による中断")
        }
        reconcile()
    }

    func requestNearby() {
        requested = true
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        reconcile()
    }

    func setConsent(_ value: Bool) {
        consent = value
        UserDefaults.standard.set(value, forKey: consentKey)
        if !value { history.interrupt(reason: "同意撤回による中断") }
        reconcile()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { reconcile() }

    private func reconcile() {
        let authorized = manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
        denied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        guard active, authorized, requested || consent else {
            manager.stopUpdatingLocation()
            locating = false
            if !authorized {
                location = nil
                history.interrupt(reason: "位置情報許可なし・中断")
                status = denied ? "位置情報を利用できません。駅名検索は利用できます。" : "位置情報は任意です。「現在地」から許可できます。"
            } else { status = "位置情報の取得は停止中です。" }
            return
        }
        locating = true
        status = consent ? "施設周辺を実験的に検知中（画面表示中のみ）" : "現在地を取得中…"
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard active, requested || consent,
              manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways,
              let fix = locations.last, fix.horizontalAccuracy >= 0,
              abs(fix.timestamp.timeIntervalSinceNow) < 15 else { return }
        location = fix
        if consent {
            if manager.accuracyAuthorization == .fullAccuracy && fix.horizontalAccuracy <= 50 {
                if history.visits.contains(where: { $0.endedAt == nil && fix.timestamp.timeIntervalSince($0.lastObservedAt) > 60 }) {
                    history.interrupt(reason: "位置情報の更新途絶による中断")
                }
                for spot in spots {
                    history.observe(id: spot.id, name: spot.name,
                                    distance: fix.distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude)),
                                    accuracy: fix.horizontalAccuracy, at: fix.timestamp)
                }
                status = "施設周辺を実験的に検知中（屋内入店は確認できません）"
            } else {
                history.interrupt(reason: "位置精度不足による中断")
                status = "位置精度が不足しています。周辺検知は保留中です。"
            }
            if history.storageError != nil {
                setConsent(false)
                status = "保存エラーのため検知を停止しました。"
            }
        }
        if requested {
            requested = false
            if !consent {
                manager.stopUpdatingLocation()
                locating = false
                status = "現在地を表示しました。駅名検索も利用できます。"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        history.interrupt(reason: "位置取得エラーによる中断")
        status = "現在地を取得できません。駅名検索を利用するか再試行してください。"
        requested = false
        if !consent { manager.stopUpdatingLocation(); locating = false }
    }
}
