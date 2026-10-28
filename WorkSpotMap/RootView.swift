import SwiftUI

struct RootView: View {
    @EnvironmentObject private var location: LocationService
    var body: some View {
        TabView {
            ExploreView()
                .tabItem { Label("空席マップ", systemImage: "map") }
            FacilityUpdateView()
                .tabItem { Label("施設用デモ", systemImage: "slider.horizontal.3") }
            VisitSettingsView(history: location.history)
                .tabItem { Label("検知・履歴", systemImage: "clock.arrow.circlepath") }
        }
        .tint(.teal)
    }
}
