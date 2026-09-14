import SwiftUI

@main
struct KollektivApp: App {
    @State private var store: HouseStore
    @State private var runner: AgentRunner
    @State private var appState: AppState

    init() {
        let store = HouseStore()
        _store = State(initialValue: store)
        _runner = State(initialValue: AgentRunner(store: store))
        let appState = AppState()
        _appState = State(initialValue: appState)
        // No-op unless the screenshot launch arguments are present.
        ScreenshotScenario.apply(store: store, appState: appState)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(runner)
                .environment(appState)
                .preferredColorScheme(.light)
                .tint(Theme.cobalt)
        }
    }
}
