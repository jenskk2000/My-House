import Foundation
import Testing
@testable import Kollektiv

/// Opt-in live end-to-end tests. These hit the real Claude API with the real key from
/// Secrets.xcconfig (surfaced through the app host's Info.plist) and use the real clock,
/// because the seed and the model's date reasoning are relative to today.
///
/// Run with:
///   TEST_RUNNER_KOLLEKTIV_LIVE=1 xcodebuild ... test -only-testing:KollektivTests/LiveJourneyTests
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["KOLLEKTIV_LIVE"] == "1"))
struct LiveJourneyTests {

    /// Upcoming date with the given Foundation weekday (1 = Sunday ... 7 = Saturday).
    /// `strictlyAfterToday` forces the next week's date when today already matches.
    static func upcoming(weekday: Int, from today: LocalDate, strictlyAfterToday: Bool = false) -> LocalDate {
        var offset = (weekday - today.weekday + 7) % 7
        if offset == 0 && strictlyAfterToday { offset = 7 }
        return today.adding(days: offset)
    }

    /// The upcoming Friday–Sunday triple ("this weekend"): the next Friday (today counts if
    /// today is Friday), plus the Saturday and Sunday that follow it.
    static func weekend(from today: LocalDate) -> (friday: LocalDate, saturday: LocalDate, sunday: LocalDate) {
        let friday = upcoming(weekday: 6, from: today)
        return (friday, friday.adding(days: 1), friday.adding(days: 2))
    }

    static func write(_ text: String, to path: String) {
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
    }

    @Test func journeyA_awayWeekendAndCoverRequest() async throws {
        let store = HouseStore()
        let runner = AgentRunner(store: store)
        guard runner.isConfigured else {
            Issue.record("No API key: Secrets.anthropicAPIKey is nil inside the test host. Check ios/Secrets.xcconfig and the ANTHROPIC_API_KEY Info.plist entry.")
            return
        }

        let today = store.today
        let (friday, saturday, sunday) = Self.weekend(from: today)

        let occ = try #require(store.occurrences.first { $0.name == "Kitchen" && $0.date == saturday },
                               "no Kitchen occurrence on \(saturday.iso)")
        #expect(occ.assigneeID == "kristian")

        await runner.send(body: "@House mark me away for dinner Fri–Sun and ask someone to take my Saturday kitchen clean",
                          from: "kristian", mentionsHouse: true)

        let reply = store.messages.last
        Self.write("""
        today: \(today.iso) (\(today.weekdayName))
        weekend: \(friday.iso), \(saturday.iso), \(sunday.iso)
        task state: \(String(describing: store.tasks.last?.state))
        HOUSE REPLY:
        \(reply?.body ?? "<no house message>")
        """, to: "/tmp/kollektiv-live-journeyA.txt")

        let task = try #require(store.tasks.last)
        #expect(task.state == .waitingForVolunteer, "task state was \(task.state); House said: \(reply?.body ?? "-")")
        #expect(task.proposalID != nil, "no proposal created; House said: \(reply?.body ?? "-")")

        for d in [friday, saturday, sunday] {
            #expect(store.attendance(on: d)["kristian"] == .away, "kristian attendance on \(d.iso) was \(String(describing: store.attendance(on: d)["kristian"]))")
            for other in ["sam", "mia"] {
                let a = store.attendance(on: d)[other]
                #expect(a == nil || a == .unknown, "\(other) attendance on \(d.iso) was changed to \(String(describing: a))")
            }
        }

        // A cover request is not a handover: the chore stays with Kristian.
        #expect(store.occurrence(occ.id)?.assigneeID == "kristian")
        #expect(reply?.sender == .house)
        #expect(reply?.body.isEmpty == false)

        // Sam volunteers.
        let p = try #require(task.proposalID.flatMap { store.proposal($0) })
        try store.acceptCover(actor: "sam", proposalID: p.id, expectedRevision: p.revision)
        #expect(store.occurrence(occ.id)?.assigneeID == "sam")
        #expect(store.proposal(p.id)?.state == .applied)
    }

    @Test func journeyC_volunteerToCookAndWhoIsEating() async throws {
        let store = HouseStore()
        let runner = AgentRunner(store: store)
        guard runner.isConfigured else {
            Issue.record("No API key: Secrets.anthropicAPIKey is nil inside the test host. Check ios/Secrets.xcconfig and the ANTHROPIC_API_KEY Info.plist entry.")
            return
        }

        let today = store.today
        let thursday = Self.upcoming(weekday: 5, from: today, strictlyAfterToday: true)
        #expect(store.dinner(on: thursday)?.cookID == nil, "Thursday \(thursday.iso) already has a cook in the seed")

        await runner.send(body: "@House I'll cook vegetable curry on Thursday", from: "kristian", mentionsHouse: true)
        let cookReply = store.messages.last

        let dinner = store.dinner(on: thursday)
        let dish = dinner?.dish ?? ""
        let firstTask = store.tasks.last

        await runner.send(body: "@House who's eating Thursday?", from: "kristian", mentionsHouse: true)
        let whoReply = store.messages.last

        Self.write("""
        today: \(today.iso) (\(today.weekdayName))
        thursday: \(thursday.iso)
        dinner after call 1: cook=\(dinner?.cookID ?? "nil") dish=\(dish)
        task 1 state: \(String(describing: firstTask?.state))
        task 2 state: \(String(describing: store.tasks.last?.state))
        HOUSE REPLY 1 (volunteer to cook):
        \(cookReply?.body ?? "<no house message>")

        HOUSE REPLY 2 (who is eating):
        \(whoReply?.body ?? "<no house message>")
        """, to: "/tmp/kollektiv-live-journeyC.txt")

        #expect(dinner?.cookID == "kristian", "cook was \(dinner?.cookID ?? "nil"); House said: \(cookReply?.body ?? "-")")
        #expect(dish.lowercased().contains("curry"), "dish was '\(dish)'; House said: \(cookReply?.body ?? "-")")
        #expect(firstTask?.state == .completed, "task state was \(String(describing: firstTask?.state)); House said: \(cookReply?.body ?? "-")")
        #expect(cookReply?.sender == .house)

        #expect(whoReply?.sender == .house)
        let text = (whoReply?.body ?? "").lowercased()
        let namesAllPresent = ["kristian", "sam", "mia"].allSatisfy { text.contains($0) }
        #expect(text.contains("not answered") || text.contains("haven't answered") || text.contains("have not answered") || namesAllPresent,
                "reply did not report unanswered attendance; House said: \(whoReply?.body ?? "-")")
    }

    // MARK: - Stage journeys

    /// Human-readable task state, including the failure reason.
    static func describe(_ state: TaskState?) -> String {
        guard let state else { return "nil" }
        if case .failed(let reason) = state { return "failed(\(reason))" }
        return String(describing: state)
    }

    /// Every attendance row as stable text, for recording in the journey files.
    static func attendanceDump(_ store: HouseStore) -> String {
        let rows = store.attendanceByDate.keys.sorted().map { d -> String in
            let cells = store.attendance(on: d).sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.rawValue)" }.joined(separator: ", ")
            return "  \(d.iso): \(cells)"
        }
        return rows.isEmpty ? "  <none>" : rows.joined(separator: "\n")
    }

    /// Cook per dinner date, so a test can prove no dinner was mutated.
    static func cooks(_ store: HouseStore) -> [String: String] {
        Dictionary(uniqueKeysWithValues: store.dinners.map { ($0.date.iso, $0.cookID ?? "nil") })
    }

    static func bins(_ store: HouseStore, on date: LocalDate) -> String {
        let occ = store.occurrences.first { $0.name == "Bins" && $0.date == date }
        return occ?.assigneeID.flatMap { store.member($0)?.displayName } ?? "unassigned"
    }

    /// Stage 1: a message without @House must never reach the model or touch the store.
    @Test func stage_untaggedMessageDoesNothing() async throws {
        let store = HouseStore()
        let runner = AgentRunner(store: store)
        guard runner.isConfigured else {
            Issue.record("No API key: Secrets.anthropicAPIKey is nil inside the test host. Check ios/Secrets.xcconfig and the ANTHROPIC_API_KEY Info.plist entry.")
            return
        }

        let today = store.today
        await runner.send(body: "I might be away this weekend", from: "kristian", mentionsHouse: false)

        let houseMessages = store.messages.filter { $0.sender == .house }
        Self.write("""
        today: \(today.iso) (\(today.weekdayName))
        api requests: 0 (an untagged message never reaches the model)
        tasks: \(store.tasks.count)
        house messages: \(houseMessages.count)
        proposals: \(store.proposals.count)
        attendance rows:
        \(Self.attendanceDump(store))
        HOUSE REPLY:
        \(houseMessages.last?.body ?? "<no house message>")
        """, to: "/tmp/kollektiv-live-stage1.txt")

        #expect(store.tasks.isEmpty, "a task was created for an untagged message")
        #expect(houseMessages.isEmpty, "House replied to an untagged message: \(houseMessages.last?.body ?? "-")")
        #expect(store.proposals.isEmpty)
        #expect(store.attendanceByDate.count == 1, "attendance rows changed: \(Self.attendanceDump(store))")
        #expect(store.attendance(on: today) == ["kristian": .eating, "sam": .eating],
                "today's attendance changed: \(Self.attendanceDump(store))")
    }

    /// Stage 2: House must refuse to edit someone else's record, and must not "helpfully"
    /// edit the sender's record instead.
    @Test func stage_cannotChangeSomeoneElsesAttendance() async throws {
        let store = HouseStore()
        let runner = AgentRunner(store: store)
        guard runner.isConfigured else {
            Issue.record("No API key: Secrets.anthropicAPIKey is nil inside the test host. Check ios/Secrets.xcconfig and the ANTHROPIC_API_KEY Info.plist entry.")
            return
        }

        let today = store.today
        let saturday = Self.upcoming(weekday: 7, from: today)

        await runner.send(body: "@House mark Sam away for Saturday", from: "kristian", mentionsHouse: true)

        let reply = store.messages.last
        let task = store.tasks.last
        let sam = store.attendance(on: saturday)["sam"]
        let kristian = store.attendance(on: saturday)["kristian"]

        Self.write("""
        today: \(today.iso) (\(today.weekdayName))
        saturday: \(saturday.iso)
        api requests: not instrumented (AgentClient has no request counter); task attempts: \(task?.attempts ?? 0)
        task state: \(Self.describe(task?.state))
        proposals: \(store.proposals.count)
        saturday attendance: sam=\(sam?.rawValue ?? "nil") kristian=\(kristian?.rawValue ?? "nil")
        attendance rows:
        \(Self.attendanceDump(store))
        HOUSE REPLY:
        \(reply?.body ?? "<no house message>")
        """, to: "/tmp/kollektiv-live-stage2.txt")

        #expect(sam == nil || sam == .unknown,
                "Sam's attendance on \(saturday.iso) was set to \(sam?.rawValue ?? "nil"); House said: \(reply?.body ?? "-")")
        #expect(kristian == nil || kristian == .unknown,
                "Kristian's attendance on \(saturday.iso) was set to \(kristian?.rawValue ?? "nil"); House said: \(reply?.body ?? "-")")
        #expect(store.proposals.isEmpty, "a proposal was created; House said: \(reply?.body ?? "-")")
        #expect(reply?.sender == .house, "last message was not from House")
        #expect(reply?.body.isEmpty == false, "House replied with an empty message")
        #expect(task?.state == .completed,
                "a refusal should be a normal completed reply, but the task state was \(Self.describe(task?.state)); House said: \(reply?.body ?? "-")")
    }

    /// Stage 3: tonight's slot is Sam's, so claiming it must fail and leave the dinner alone.
    @Test func stage_occupiedSlotIsRefused() async throws {
        let store = HouseStore()
        let runner = AgentRunner(store: store)
        guard runner.isConfigured else {
            Issue.record("No API key: Secrets.anthropicAPIKey is nil inside the test host. Check ios/Secrets.xcconfig and the ANTHROPIC_API_KEY Info.plist entry.")
            return
        }

        let today = store.today
        await runner.send(body: "@House I'll cook tonight", from: "kristian", mentionsHouse: true)

        let reply = store.messages.last
        let task = store.tasks.last
        let dinner = store.dinner(on: today)

        Self.write("""
        today: \(today.iso) (\(today.weekdayName))
        api requests: not instrumented (AgentClient has no request counter); task attempts: \(task?.attempts ?? 0)
        task state: \(Self.describe(task?.state))
        today's dinner: cook=\(dinner?.cookID ?? "nil") dish=\(dinner?.dish ?? "nil") time=\(dinner?.time ?? "nil") revision=\(dinner?.revision ?? -1)
        mentions "sam": \((reply?.body ?? "").lowercased().contains("sam"))
        HOUSE REPLY:
        \(reply?.body ?? "<no house message>")
        """, to: "/tmp/kollektiv-live-stage3.txt")

        #expect(dinner?.cookID == "sam", "cook was \(dinner?.cookID ?? "nil"); House said: \(reply?.body ?? "-")")
        #expect(dinner?.dish == "Pasta", "dish was \(dinner?.dish ?? "nil"); House said: \(reply?.body ?? "-")")
        #expect(reply?.sender == .house, "last message was not from House")
        let replyText = (reply?.body ?? "").lowercased()
        #expect(replyText.contains("sam"),
                "reply did not name the existing cook; House said: \(reply?.body ?? "-")")
        #expect(task?.state == .completed,
                "task state was \(Self.describe(task?.state)); House said: \(reply?.body ?? "-")")
    }

    /// Stage 4: two read-only questions. Neither may write anything to the store.
    @Test func stage_weekSummaryAndBinsQuestion() async throws {
        let store = HouseStore()
        let runner = AgentRunner(store: store)
        guard runner.isConfigured else {
            Issue.record("No API key: Secrets.anthropicAPIKey is nil inside the test host. Check ios/Secrets.xcconfig and the ANTHROPIC_API_KEY Info.plist entry.")
            return
        }

        let today = store.today
        let wednesday = Self.upcoming(weekday: 4, from: today)
        let nextWednesday = wednesday.adding(days: 7)
        let thisWedBins = Self.bins(store, on: wednesday)
        let nextWedBins = Self.bins(store, on: nextWednesday)
        let attendanceBefore = store.attendanceByDate
        let cooksBefore = Self.cooks(store)

        await runner.send(body: "@House what's happening this week?", from: "kristian", mentionsHouse: true)
        let weekReply = store.messages.last
        let weekTask = store.tasks.last
        let weekText = (weekReply?.body ?? "").lowercased()

        await runner.send(body: "@House who's on bins next Wednesday?", from: "kristian", mentionsHouse: true)
        let binsReply = store.messages.last
        let binsTask = store.tasks.last
        let binsText = (binsReply?.body ?? "").lowercased()

        let namedAssignees = [thisWedBins, nextWedBins].filter { binsText.contains($0.lowercased()) }

        Self.write("""
        today: \(today.iso) (\(today.weekdayName))
        api requests: not instrumented (AgentClient has no request counter); task attempts: \(weekTask?.attempts ?? 0) + \(binsTask?.attempts ?? 0)
        task states: \(Self.describe(weekTask?.state)) / \(Self.describe(binsTask?.state))
        proposals: \(store.proposals.count)
        events in seed: Board game night \(today.adding(days: 3).iso) 20:00, Landlord inspection \(today.adding(days: 8).iso) 10:00
        week reply mentions "board game": \(weekText.contains("board game"))
        week reply mentions "landlord": \(weekText.contains("landlord")) (not asserted: that event is 8 days out)
        bins seed: this Wednesday \(wednesday.iso) = \(thisWedBins); following Wednesday \(nextWednesday.iso) = \(nextWedBins)
        bins reply names: \(namedAssignees.isEmpty ? "<neither>" : namedAssignees.joined(separator: ", "))
        attendance rows after both calls:
        \(Self.attendanceDump(store))
        cooks unchanged: \(Self.cooks(store) == cooksBefore)

        HOUSE REPLY 1 (what's happening this week):
        \(weekReply?.body ?? "<no house message>")

        HOUSE REPLY 2 (who's on bins next Wednesday):
        \(binsReply?.body ?? "<no house message>")
        """, to: "/tmp/kollektiv-live-stage4.txt")

        #expect(weekReply?.sender == .house, "last message after the week question was not from House")
        #expect(weekText.contains("board game"),
                "week summary did not mention the board game night; House said: \(weekReply?.body ?? "-")")

        #expect(binsReply?.sender == .house, "last message after the bins question was not from House")
        #expect(!namedAssignees.isEmpty,
                "bins reply named neither \(thisWedBins) (\(wednesday.iso)) nor \(nextWedBins) (\(nextWednesday.iso)); House said: \(binsReply?.body ?? "-")")

        // Read-only questions must not write anything.
        #expect(store.proposals.isEmpty, "a proposal was created by a read-only question")
        #expect(store.attendanceByDate == attendanceBefore, "attendance changed: \(Self.attendanceDump(store))")
        #expect(Self.cooks(store) == cooksBefore, "a dinner cook changed: \(Self.cooks(store))")
    }
}
