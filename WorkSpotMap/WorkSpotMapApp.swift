import SwiftUI

@main
struct WorkSpotMapApp: App {
    @StateObject private var store = SpotStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
