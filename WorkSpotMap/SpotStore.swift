import Foundation

@MainActor
final class SpotStore: ObservableObject {
    @Published private(set) var spots: [Spot] = []
    @Published private(set) var profiles: [String: FacilityProfile] = [:]
    private let defaults: UserDefaults
    private let profileKey = "workspot_facility_profiles_v2"
    private let savedKey = "workspot_sample_crowd_levels_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode([String: FacilityProfile].self, from: data) {
            profiles = saved
        }
        var samples = Self.samples
        if let saved = defaults.dictionary(forKey: savedKey) as? [String: String] {
            for index in samples.indices {
                if let raw = saved[samples[index].id.uuidString], let level = CrowdLevel(rawValue: raw) {
                    samples[index].crowd = level
                }
            }
        }
        for index in samples.indices {
            if let profile = profiles[samples[index].id.uuidString] { samples[index].name = profile.name }
        }
        spots = samples
    }

    func update(_ id: UUID, to level: CrowdLevel) {
        guard let index = spots.firstIndex(where: { $0.id == id }) else { return }
        spots[index].crowd = level
        let values = Dictionary(uniqueKeysWithValues: spots.map { ($0.id.uuidString, $0.crowd.rawValue) })
        defaults.set(values, forKey: savedKey)
    }

    func profile(for spot: Spot) -> FacilityProfile {
        profiles[spot.id.uuidString] ?? FacilityProfile(name: spot.name)
    }

    @discardableResult
    func saveProfile(_ profile: FacilityProfile, for id: UUID) -> Bool {
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = spots.firstIndex(where: { $0.id == id }) else { return false }
        var cleaned = profile
        cleaned.name = name
        var updated = profiles
        updated[id.uuidString] = cleaned
        guard let data = try? JSONEncoder().encode(updated) else { return false }
        defaults.set(data, forKey: profileKey)
        profiles = updated
        spots[index].name = name
        return true
    }

    // 全50件が架空の施設です。座標は新宿・早稲田周辺に分散させた表示密度テスト用です。
    // 実在店舗の混雑状況を表すものではありません。
    private static let samples: [Spot] = {
        let categoryNames = ["カフェ", "図書館", "自習室", "ワークスペース"]
        let categories: [SpotCategory] = [.cafe, .library, .study, .coworking]
        let levels: [CrowdLevel] = [.available, .busy, .full, .unknown]
        return (0..<50).map { i in
            // deterministic pseudo-random placement, not actual business locations
            let latOffset = (Double((i * 17 + 13) % 101) / 100 - 0.5) * 0.054
            let lonOffset = (Double((i * 43 + 27) % 103) / 102 - 0.5) * 0.054
            let category = i == 0 ? SpotCategory.cafe : categories[i % categories.count]
            let crowd = i == 0 ? CrowdLevel.available : levels[(i * 7 + 1) % levels.count]
            return Spot(
                id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", i + 1))!,
                name: i == 0 ? "PR・サンプルカフェ" : String(format: "サンプル・%@%02d", categoryNames[i % 4], i + 1),
                category: category,
                latitude: 35.695 + latOffset,
                longitude: 139.705 + lonOffset,
                address: "東京都新宿区周辺（架空の施設）",
                note: "混雑度とピン密度を確認するためのデモデータです。",
                hasWifi: i % 3 != 0,
                hasPower: i % 4 != 0,
                crowd: crowd,
                isSponsored: i == 0
            )
        }
    }()
}
