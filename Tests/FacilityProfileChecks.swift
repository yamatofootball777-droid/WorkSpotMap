import Foundation

@main
struct FacilityProfileChecks {
    @MainActor static func main() {
        let suite = "WorkSpotProfileTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = "00000000-0000-4000-8000-000000000001"
        defaults.set([id: "満席"], forKey: "workspot_sample_crowd_levels_v1")
        let store = SpotStore(defaults: defaults)
        let spot = store.spots[0]
        assert(store.spots.count == 50 && spot.isSponsored && spot.crowd == .full)
        let profile = FacilityProfile(name: " 新しいカフェ ", menu: "秋限定ラテ 600円\nケーキ", hours: "9〜18時", memo: "11/1 臨時休業")
        assert(store.saveProfile(profile, for: spot.id))
        store.update(spot.id, to: .busy)
        let restored = SpotStore(defaults: defaults)
        let saved = restored.profile(for: restored.spots[0])
        assert(restored.spots[0].name == "新しいカフェ" && restored.spots[0].crowd == .busy)
        assert(saved.menu == profile.menu && saved.hours == profile.hours && saved.memo == profile.memo)
        assert(restored.spots[1].name == store.spots[1].name)
        assert(!store.saveProfile(FacilityProfile(name: " \n "), for: spot.id))
        assert(store.saveProfile(FacilityProfile(name: "カフェ"), for: spot.id))
        assert(SpotStore(defaults: defaults).profile(for: spot).menu.isEmpty)
        print("PASS: v1 migration, profile persistence, map name, independent facilities, validation, clearing")
    }
}
