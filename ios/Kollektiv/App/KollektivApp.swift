import SwiftUI

@main
struct KollektivApp: App {
    @State private var store = HouseStore()
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(appState)
                .preferredColorScheme(.light)
                .tint(Theme.cobalt)
        }
    }
}
