import SwiftUI

struct ChoresView: View {
    @Environment(HouseStore.self) private var store
    @State private var errorText: String?

    var body: some View {
        let groups = store.choreGroups(for: store.currentMemberID)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("A fresh\nhouse.").font(Theme.heading(54))
                Image("chores").resizable().scaledToFit()
                    .frame(width: 185, height: 185)
                    .background(Theme.cream, in: Circle())
                    .frame(maxWidth: .infinity).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 26) {
                    section("Your turn", groups.yourTurn, empty: "Nothing assigned to you right now.")
                    section("Coming up", groups.comingUp, empty: "No other chores this month.")
                    section("Needs someone", groups.needsSomeone, empty: "Everything is claimed.")
                    if let errorText { Text(errorText).font(Theme.body).foregroundStyle(Theme.navy) }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 28))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .foregroundStyle(Theme.navy)
        .background(Theme.coral.ignoresSafeArea())
        .navigationTitle("Chores")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.coral, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func section(_ title: String, _ items: [ChoreOccurrence], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(Theme.title(24))
            if items.isEmpty { Text(empty).font(Theme.body).foregroundStyle(Theme.navy.opacity(0.65)) }
            ForEach(items) { occurrence in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(occurrence.name).font(Theme.title(20))
                            Text(occurrence.date.shortLabel).font(Theme.body).foregroundStyle(Theme.navy.opacity(0.65))
                            if let assignee = occurrence.assigneeID.flatMap({ store.member($0) }) {
                                Text(assignee.id == store.currentMemberID ? "Your turn" : assignee.displayName)
                                    .font(Theme.caption.bold())
                            }
                        }
                        Spacer(minLength: 4)
                        if occurrence.assigneeID == store.currentMemberID {
                            Button {
                                do { try store.completeChore(actor: store.currentMemberID, occurrenceID: occurrence.id); errorText = nil }
                                catch { errorText = error.localizedDescription }
                            } label: {
                                Label("Done", systemImage: "checkmark")
                                    .font(Theme.body.bold()).padding(.horizontal, 16).padding(.vertical, 13)
                                    .foregroundStyle(.white).background(Theme.cobalt, in: Capsule())
                            }.buttonStyle(.plain)
                            .accessibilityLabel("Mark \(occurrence.name) on \(occurrence.date.shortLabel) done")
                        }
                    }
                    if store.openProposal(forOccurrence: occurrence.id) != nil {
                        Pill(text: "Cover pending", color: Theme.navy, background: Theme.butter)
                    }
                    if occurrence.id != items.last?.id { Divider().padding(.top, 6) }
                }
            }
        }
    }
}
