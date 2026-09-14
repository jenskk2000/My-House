import Foundation

/// Launch-argument driven demo state, used only to capture README screenshots.
/// Inert unless one of the recognised arguments is present.
///
///   -scenario journeyA-pending|journeyA-accepted|journeyC
///   -tab house|chat|week   -person kristian|sam|mia   -sheet today   -chores
@MainActor
enum ScreenshotScenario {
    private static func value(_ flag: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    private static func has(_ flag: String) -> Bool { CommandLine.arguments.contains(flag) }

    private static func monthName(_ date: LocalDate) -> String {
        let f = DateFormatter()
        f.calendar = LocalDate.calendar; f.timeZone = LocalDate.timeZone
        f.locale = LocalDate.calendar.locale; f.dateFormat = "MMMM"
        return f.string(from: date.noon)
    }

    /// Upcoming date with the given Foundation weekday (1 = Sunday ... 7 = Saturday).
    private static func upcoming(_ weekday: Int, from today: LocalDate, strictlyAfter: Bool = false) -> LocalDate {
        var offset = (weekday - today.weekday + 7) % 7
        if offset == 0 && strictlyAfter { offset = 7 }
        return today.adding(days: offset)
    }

    static func apply(store: HouseStore, appState: AppState) {
        let scenario = value("-scenario")
        let tab = value("-tab")
        let person = value("-person")
        guard scenario != nil || tab != nil || person != nil || has("-sheet") || has("-chores") else { return }

        store.currentMemberID = person ?? (scenario == "journeyC" ? "kristian" : scenario != nil ? "sam" : store.currentMemberID)
        switch tab {
        case "chat": appState.selectedTab = .chat
        case "week": appState.selectedTab = .week
        case "house": appState.selectedTab = .house
        default: break
        }
        // Posted after launch so the chat's scroll-to-latest fires and the sheet/push have a
        // live view hierarchy to attach to.
        let wantsSheet = value("-sheet") == "today", wantsChores = has("-chores")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch scenario {
            case "journeyA-pending": journeyA(store: store, accepted: false)
            case "journeyA-accepted": journeyA(store: store, accepted: true)
            case "journeyC": journeyC(store: store)
            default: break
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if wantsSheet { appState.presentedDinnerDate = store.today }
                if wantsChores { appState.showChores = true }
            }
        }
    }

    private static func journeyA(store: HouseStore, accepted: Bool) {
        let today = store.today
        let friday = upcoming(6, from: today)
        let saturday = friday.adding(days: 1), sunday = friday.adding(days: 2)
        guard let kitchen = store.occurrences.first(where: { $0.name == "Kitchen" && $0.date == saturday }) else { return }
        let source = store.postMessage(
            sender: .member("kristian"),
            body: "@House mark me away for dinner Fri–Sun and ask someone to take my Saturday kitchen clean",
            mentionsHouse: true)
        let task = store.createTask(initiator: "kristian", sourceMessageID: source.id)
        do {
            try store.setAttendance(actor: "kristian", dates: [friday, saturday, sunday], status: .away)
            let proposal = try store.createCoverProposal(actor: "kristian", occurrenceID: kitchen.id, taskID: task.id)
            let month = monthName(saturday)
            store.postMessage(sender: .house, body: """
            You're marked away for dinner Friday \(friday.day), Saturday \(saturday.day) and Sunday \(sunday.day) \(month). \
            A cover request has been posted for your Saturday \(saturday.day) \(month) kitchen chore — it's still yours \
            until Sam or Mia volunteers to take it.
            """, taskID: task.id)
            store.updateTask(task.id) { $0.state = .waitingForVolunteer; $0.proposalID = proposal.id }
            guard accepted else { return }
            try store.acceptCover(actor: "sam", proposalID: proposal.id, expectedRevision: proposal.revision)
            store.postMessage(sender: .house, body: "Kitchen on Saturday \(saturday.day) \(month) → Sam. Chore schedule updated.")
            store.updateTask(task.id) { $0.state = .completed }
        } catch {
            // Screenshot mode only: a half-applied scenario is better than a crash.
        }
    }

    private static func journeyC(store: HouseStore) {
        let today = store.today
        let thursday = upcoming(5, from: today, strictlyAfter: true)
        let month = monthName(thursday)
        let first = store.postMessage(sender: .member("kristian"), body: "@House I'll cook vegetable curry on Thursday", mentionsHouse: true)
        let task1 = store.createTask(initiator: "kristian", sourceMessageID: first.id)
        try? store.volunteerToCook(actor: "kristian", date: thursday, dish: "Vegetable curry", time: nil)
        store.postMessage(sender: .house, body: """
        You're set to cook vegetable curry on Thursday \(thursday.day) \(month). Note there's also Board game night \
        that evening at 20:00, so good timing for a shared meal.
        """, taskID: task1.id)
        store.updateTask(task1.id) { $0.state = .completed }

        let second = store.postMessage(sender: .member("kristian"), body: "@House who's eating Thursday?", mentionsHouse: true)
        let task2 = store.createTask(initiator: "kristian", sourceMessageID: second.id)
        store.postMessage(sender: .house, body: """
        For Thursday \(thursday.day) \(month), nobody has responded yet — Kristian, Sam, and Mia are all "Not answered."
        """, taskID: task2.id)
        store.updateTask(task2.id) { $0.state = .completed }
    }
}
