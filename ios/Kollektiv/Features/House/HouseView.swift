import SwiftUI

struct HouseView: View {
    @Environment(HouseStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Kollektiv").font(Theme.title(20)).foregroundStyle(Theme.navy)
                        Spacer()
                        DemoPersonMenu()
                    }
                    Text("Our house.")
                        .font(Theme.heading(44))
                        .foregroundStyle(Theme.navy)

                    Image("house")
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 250)
                        .padding(.horizontal, 24)
                        .accessibilityHidden(true)

                    HStack(spacing: 12) {
                        DoorButton(title: "Meals", systemImage: "fork.knife", color: Theme.coral, badge: nil) {
                            appState.presentedDinnerDate = store.today
                        }
                        DoorButton(title: "Chores", systemImage: "sparkles", color: Theme.cobalt, badge: pendingChoreBadge) {
                            appState.showChores = true
                        }
                        DoorButton(title: "Plans", systemImage: "calendar", color: Theme.teal, badge: nil) {
                            appState.selectedTab = .week
                        }
                    }

                    StatusStrip()

                    PrimaryButton(title: "Ask the house", systemImage: "sparkle") {
                        appState.composerDraft = "@House "
                        appState.mentionHouse = true
                        appState.selectedTab = .chat
                    }

                    Text("Demo mode · data resets on relaunch")
                        .font(Theme.caption).foregroundStyle(Theme.navy.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .background(Theme.butter.ignoresSafeArea())
            .navigationDestination(isPresented: $appState.showChores) {
                ChoresView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var pendingChoreBadge: String? {
        let n = store.proposals.filter { $0.state == .awaitingVolunteer }.count
        return n > 0 ? "\(n) pending" : nil
    }
}

private struct DoorButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let badge: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage).font(.title2.bold())
                Text(title).font(.system(.subheadline, design: .rounded).weight(.bold))
                if let badge { Pill(text: badge, color: Theme.navy, background: Theme.butter) }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(color, in: UnevenRoundedRectangle(topLeadingRadius: 40, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 40))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(badge.map { ", \($0)" } ?? "")")
    }
}

/// One line: outstanding decision first, otherwise tonight's dinner count.
private struct StatusStrip: View {
    @Environment(HouseStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            if store.proposals.contains(where: { $0.state == .awaitingVolunteer }) {
                appState.selectedTab = .chat
            } else {
                appState.presentedDinnerDate = store.today
            }
        } label: {
            HStack {
                Image(systemName: icon).foregroundStyle(Theme.navy)
                Text(text).font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(Theme.navy)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.navy.opacity(0.5))
            }
            .padding(16)
            .background(Theme.cream, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var pending: CoverProposal? { store.proposals.first { $0.state == .awaitingVolunteer } }
    private var icon: String { pending != nil ? "hand.raised.fill" : "fork.knife" }
    private var text: String {
        if let p = pending, let occ = store.occurrence(p.occurrenceID) {
            return "Needs a volunteer: \(occ.name) on \(occ.date.shortLabel)"
        }
        let split = store.attendanceSplit(on: store.today)
        let dish = store.dinner(on: store.today)?.dish
        return "Tonight: \(split.eating.count) eating" + (dish.map { " · \($0)" } ?? "")
    }
}
