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
                        Text("My House").font(Theme.title(20)).foregroundStyle(Theme.navy)
                        Spacer()
                        DemoPersonMenu()
                    }
                    HouseFacade {
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

                    HomeCalendarWidget()

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

private struct HomeCalendarWidget: View {
    @Environment(HouseStore.self) private var store
    @Environment(AppState.self) private var appState

    private var upcoming: [HouseEvent] {
        Array(store.events.filter { $0.date >= store.today && $0.date < store.today.adding(days: 7) }
            .sorted { ($0.date, $0.time ?? "") < ($1.date, $1.time ?? "") }.prefix(3))
    }

    var body: some View {
        Button { appState.selectedTab = .week } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Coming up").font(Theme.title(20))
                    Spacer()
                    Text("This week").font(Theme.caption)
                    Image(systemName: "chevron.right").font(.caption.bold())
                }
                HStack(spacing: 5) {
                    ForEach(0..<7) { offset in
                        let date = store.today.adding(days: offset)
                        VStack(spacing: 5) {
                            Text(String(date.weekdayName.prefix(1))).font(Theme.caption)
                            Text("\(date.day)").font(Theme.body.bold())
                            Circle().fill(store.events.contains { $0.date == date } ? Theme.coral : .clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .foregroundStyle(offset == 0 ? .white : Theme.navy)
                        .background(offset == 0 ? Theme.cobalt : .clear, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if upcoming.isEmpty {
                    Text("No shared events this week").font(Theme.body).foregroundStyle(Theme.navy.opacity(0.65))
                } else {
                    ForEach(upcoming) { event in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.coral).frame(width: 4)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title).font(Theme.body.bold())
                                Text(event.date.shortLabel + (event.time.map { " · " + $0 } ?? ""))
                                    .font(Theme.caption).foregroundStyle(Theme.navy.opacity(0.65))
                            }
                            Spacer(minLength: 0)
                        }.fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .foregroundStyle(Theme.navy).padding(18)
            .background(Theme.cream, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the shared week")
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
                Image(systemName: systemImage).font(.system(size: 30, weight: .bold))
                Text(title).font(.system(.subheadline, design: .rounded).weight(.bold))
                if let badge { Pill(text: badge, color: Theme.navy, background: Theme.butter) }
            }
            .foregroundStyle(Theme.navy)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 95)
            .background(color, in: UnevenRoundedRectangle(topLeadingRadius: 40, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 40))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(badge.map { ", \($0)" } ?? "")")
    }
}

/// The doors are actual controls inside the house, rather than decoration below it.
private struct HouseFacade<Doors: View>: View {
    @ViewBuilder let doors: () -> Doors

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .bottom) {
                // Fill the gable so the page background cannot show beneath the roof.
                Path { path in
                    path.move(to: CGPoint(x: 14, y: 100))
                    path.addLine(to: CGPoint(x: width / 2, y: 24))
                    path.addLine(to: CGPoint(x: width - 14, y: 100))
                    path.closeSubpath()
                }
                .fill(Theme.cream)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.cream)
                    .frame(width: width - 28, height: 180)
                Path { path in
                    path.move(to: CGPoint(x: 10, y: 100))
                    path.addLine(to: CGPoint(x: width / 2, y: 24))
                    path.addLine(to: CGPoint(x: width - 10, y: 100))
                }
                .stroke(Theme.cobalt, style: StrokeStyle(lineWidth: 28, lineCap: .round, lineJoin: .round))
                RoundedRectangle(cornerRadius: 5)
                    .fill(Theme.cobalt)
                    .frame(width: 27, height: 60)
                    .position(x: width - 57, y: 61)
                HStack(spacing: 26) {
                    Capsule().frame(width: 10, height: 16)
                    Capsule().frame(width: 10, height: 16)
                }
                .foregroundStyle(Theme.navy)
                .position(x: width / 2, y: 115)
                Path { path in
                    path.move(to: CGPoint(x: width / 2 - 16, y: 135))
                    path.addQuadCurve(to: CGPoint(x: width / 2 + 16, y: 135), control: CGPoint(x: width / 2, y: 153))
                }
                .stroke(Theme.navy, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                HStack(alignment: .bottom, spacing: 10) { doors() }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 0)
            }
        }
        .frame(height: 260)
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
