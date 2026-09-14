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
}
