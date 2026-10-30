import SwiftUI

@main
struct WorkSpotMapApp: App {
    @StateObject private var store = SpotStore()
    @StateObject private var location = LocationService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(location)
                .onAppear { location.setActive(scenePhase == .active, spots: store.spots) }
                .onChange(of: scenePhase) { _, phase in location.setActive(phase == .active, spots: store.spots) }
        }
    }
}
