import SwiftUI

/// Demo-only identity switcher for the chat toolbar (stands in for auth in M1).
struct ChatDemoPersonMenu: View {
    @Environment(HouseStore.self) private var store
    var body: some View {
        Menu {
            Section("Demo person") {
                ForEach(store.members) { m in
                    Button { store.currentMemberID = m.id } label: {
                        Label(m.displayName, systemImage: m.id == store.currentMemberID ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                MemberAvatar(member: store.currentMember, size: 24)
                Text("Demo: \(store.currentMember.displayName)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                Image(systemName: "chevron.down").font(.caption2.bold())
            }
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.cream, in: Capsule())
        }
        .accessibilityLabel("Switch demo person, currently \(store.currentMember.displayName)")
    }
}
