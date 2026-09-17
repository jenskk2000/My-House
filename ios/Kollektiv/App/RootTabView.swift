import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @State private var keyboardVisible = false

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            TabView(selection: $appState.selectedTab) {
                HouseView()
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("House", systemImage: "house.fill") }
                    .tag(AppTab.house)
                ChatView()
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(AppTab.chat)
                WeekView()
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("Week", systemImage: "calendar") }
                    .tag(AppTab.week)
            }
            if !keyboardVisible {
                HStack(spacing: 8) {
                    navigationItem("House", icon: "house.fill", tab: .house)
                    navigationItem("Chat", icon: "bubble.left.and.bubble.right.fill", tab: .chat)
                    navigationItem("Week", icon: "calendar", tab: .week)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .background(Theme.cream.ignoresSafeArea(edges: .bottom))
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.navy.opacity(0.08)).frame(height: 1)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        // The only dinner sheet in the app; House, the status strip and Week all drive it.
        .sheet(item: $appState.presentedDinnerDate) { DinnerSheet(date: $0) }
    }

    private func navigationItem(_ title: String, icon: String, tab: AppTab) -> some View {
        let selected = appState.selectedTab == tab
        return Button { appState.selectedTab = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selected ? Theme.cobalt : Theme.navy)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(selected ? Theme.cobalt.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
