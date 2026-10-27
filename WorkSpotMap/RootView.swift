import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ExploreView()
                .tabItem { Label("空席マップ", systemImage: "map") }
            FacilityUpdateView()
                .tabItem { Label("施設用デモ", systemImage: "slider.horizontal.3") }
        }
        .tint(.teal)
    }
}
