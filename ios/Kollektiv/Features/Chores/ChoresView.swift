import SwiftUI

struct ChoresView: View {
    @Environment(HouseStore.self) private var store
    @State private var errorText: String?

    var body: some View {
        let groups = store.choreGroups(for: store.currentMemberID)
        List {
            Section {
                Image("chores").resizable().scaledToFit().frame(height: 120).frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            section("Your turn", groups.yourTurn, empty: "Nothing assigned to you right now.")
            section("Needs someone", groups.needsSomeone, empty: "Everything is claimed.")
            section("Coming up", groups.comingUp, empty: "No other chores this month.")
            if let errorText { Text(errorText).foregroundStyle(Theme.coral) }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.coral.opacity(0.12).ignoresSafeArea())
        .navigationTitle("Chores")
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [ChoreOccurrence], empty: String) -> some View {
        Section(title) {
            if items.isEmpty { Text(empty).foregroundStyle(.secondary) }
            ForEach(items) { occ in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(occ.name).font(Theme.body.bold())
                        Text(occ.date.shortLabel).font(Theme.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let assignee = occ.assigneeID.flatMap({ store.member($0) }) { MemberAvatar(member: assignee, size: 28) }
                    if store.openProposal(forOccurrence: occ.id) != nil {
                        Pill(text: "Cover pending", color: .white, background: Theme.coral)
                    }
                    if occ.assigneeID == store.currentMemberID {
                        Button("Done") {
                            do { try store.completeChore(actor: store.currentMemberID, occurrenceID: occ.id); errorText = nil }
                            catch { errorText = error.localizedDescription }
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .buttonStyle(.borderedProminent).tint(Theme.teal)
                    }
                }
            }
        }
    }
}
