import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            HouseView()
                .tabItem { Label("House", systemImage: "house.fill") }
                .tag(AppTab.house)
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppTab.chat)
            WeekView()
                .tabItem { Label("Week", systemImage: "calendar") }
                .tag(AppTab.week)
        }
    }
}
