import SwiftUI

struct WeekView: View {
    @Environment(HouseStore.self) private var store
    @Environment(AppState.self) private var appState
    @State private var weekOffset = 0

    var body: some View {
        let start = store.today.adding(days: weekOffset * 7)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Our\nweek.").font(Theme.heading(54))
                        Spacer()
                        Image("calendar").resizable().scaledToFit()
                            .frame(width: 125, height: 125).accessibilityHidden(true)
                    }
                    HStack {
                        Button { weekOffset = max(0, weekOffset - 1) } label: {
                            Image(systemName: "chevron.left").frame(width: 44, height: 48)
                        }.disabled(weekOffset == 0).accessibilityLabel("Previous week")
                        Spacer(minLength: 0)
                        Text("\(start.shortLabel) – \(start.adding(days: 6).shortLabel)")
                            .font(Theme.title(16)).multilineTextAlignment(.center)
                        Spacer(minLength: 0)
                        Button { weekOffset = min(1, weekOffset + 1) } label: {
                            Image(systemName: "chevron.right").frame(width: 44, height: 48)
                        }.disabled(weekOffset == 1).accessibilityLabel("Next week")
                    }
                    .foregroundStyle(.white)
                    .background(Theme.cobalt, in: Capsule())
                    if weekOffset != 0 {
                        Button("Back to today") { weekOffset = 0 }.font(Theme.body.bold())
                    }
                    ForEach(store.weekItems(from: start), id: \.date) { day in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(day.date == store.today ? "TODAY · \(day.date.shortLabel)" : day.date.shortLabel.uppercased())
                                .font(Theme.caption.bold()).foregroundStyle(Theme.navy.opacity(0.65))
                            if day.items.isEmpty { Text("Nothing planned").font(Theme.body) }
                            ForEach(day.items) { item in row(item) }
                        }
                    }
                }
                .padding(24)
                .padding(.bottom, 16)
            }
            .foregroundStyle(Theme.navy)
            .background(Theme.cream.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func row(_ item: WeekItem) -> some View {
        switch item {
        case .dinner(let dinner):
            Button { appState.presentedDinnerDate = dinner.date } label: {
                illustratedRow("meals", title: dinner.dish ?? "Dinner to plan",
                               subtitle: "\(dinner.time.map { $0 + " · " } ?? "")\(store.attendanceSplit(on: dinner.date).eating.count) eating",
                               detail: dinner.cookID.flatMap { store.member($0)?.displayName }.map { $0 + " cooks" } ?? "No cook yet",
                               navigates: true)
            }.buttonStyle(.plain)
        case .chore(let chore):
            illustratedRow("chores", title: chore.name,
                           subtitle: chore.assigneeID.flatMap { store.member($0)?.displayName } ?? "Needs someone",
                           detail: chore.isCompleted ? "Completed" : (store.openProposal(forOccurrence: chore.id) != nil ? "Cover pending" : "To do"))
        case .event(let event):
            illustratedRow("calendar", title: event.title, subtitle: event.time ?? "All day", detail: "House plan")
        }
    }

    private func illustratedRow(_ asset: String, title: String, subtitle: String, detail: String, navigates: Bool = false) -> some View {
        HStack(spacing: 16) {
            Image(asset).resizable().scaledToFit().frame(width: 64, height: 64).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(Theme.title(20))
                Text(subtitle).font(Theme.body).foregroundStyle(Theme.navy.opacity(0.7))
                Text(detail).font(Theme.caption).foregroundStyle(Theme.navy.opacity(0.6))
            }
            Spacer(minLength: 0)
            if navigates { Image(systemName: "chevron.right").font(.body.bold()) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }
}
