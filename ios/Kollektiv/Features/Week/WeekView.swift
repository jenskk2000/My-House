import SwiftUI

struct WeekView: View {
    @Environment(HouseStore.self) private var store
    @Environment(AppState.self) private var appState
    @State private var weekOffset = 0

    var body: some View {
        let start = store.today.adding(days: weekOffset * 7)
        NavigationStack {
            List {
                ForEach(store.weekItems(from: start), id: \.date) { day in
                    Section {
                        if day.items.isEmpty { Text("Nothing planned").foregroundStyle(.secondary) }
                        ForEach(day.items) { item in row(item) }
                    } header: {
                        Text(day.date == store.today ? "Today · \(day.date.shortLabel)" : day.date.longLabel)
                            .font(Theme.title(16)).foregroundStyle(Theme.navy)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.teal.opacity(0.10).ignoresSafeArea())
            .navigationTitle("Week")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { weekOffset = max(0, weekOffset - 1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous week")
                        .disabled(weekOffset <= 0)
                    Button("Today") { weekOffset = 0 }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .disabled(weekOffset == 0)
                    Button { weekOffset = min(1, weekOffset + 1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next week")
                        .disabled(weekOffset >= 1)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: WeekItem) -> some View {
        switch item {
        case .dinner(let d):
            Button { appState.presentedDinnerDate = d.date } label: {
                HStack {
                    Label(d.dish ?? "Dinner · not planned", systemImage: "fork.knife").font(Theme.body)
                    Spacer()
                    let split = store.attendanceSplit(on: d.date)
                    Text("\(split.eating.count) eating").font(Theme.caption).foregroundStyle(.secondary)
                    if let cook = d.cookID.flatMap(store.member) { MemberAvatar(member: cook, size: 24) }
                }
            }.foregroundStyle(Theme.navy)
        case .chore(let c):
            HStack {
                Label(c.name, systemImage: "sparkles").font(Theme.body)
                Spacer()
                if store.openProposal(forOccurrence: c.id) != nil { Pill(text: "Cover pending", color: .white, background: Theme.coral) }
                if c.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.teal)
                        .accessibilityLabel("Completed")
                }
                if let a = c.assigneeID.flatMap(store.member) { MemberAvatar(member: a, size: 24) } else { Pill(text: "Needs someone") }
            }
        case .event(let e):
            HStack {
                Label(e.title, systemImage: "calendar").font(Theme.body)
                Spacer()
                if let t = e.time { Text(t).font(Theme.caption).foregroundStyle(.secondary) }
            }
        }
    }
}
