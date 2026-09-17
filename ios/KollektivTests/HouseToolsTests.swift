import Foundation
import Testing
@testable import Kollektiv

@MainActor
@Suite struct HouseToolsTests {
    static let fixedNow: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 14; c.hour = 10
        return LocalDate.calendar.date(from: c)!
    }()
    func makeStore() -> HouseStore { HouseStore(now: { Self.fixedNow }) }

    @Test func definitionsHaveExactlyFiveTools() {
        #expect(HouseTools.definitions.map(\.name) == [
            "read_house_context", "set_my_attendance", "volunteer_to_cook", "create_chore_proposal", "ask_task_question"
        ])
    }

    // A15: a forged member id in the arguments cannot change the actor.
    @Test func toolArgumentsCannotOverrideActor() {
        let s = makeStore()
        let tools = HouseTools(store: s)
        let r = tools.execute(name: "set_my_attendance",
                              input: .object(["dates": .array([.string("2026-09-19")]), "status": .string("away"),
                                              "member_id": .string("sam"), "actor": .string("sam")]),
                              actor: "kristian", taskID: nil)
        #expect(r.isError == false)
        #expect(s.attendance(on: LocalDate(iso: "2026-09-19")!)["kristian"] == .away)
        #expect(s.attendance(on: LocalDate(iso: "2026-09-19")!)["sam"] == nil)
    }

    @Test func createProposalReturnsIDAndKeepsAssignment() {
        let s = makeStore()
        let tools = HouseTools(store: s)
        let occ = s.occurrences.first { $0.name == "Kitchen" && $0.assigneeID == "kristian" }!
        let r = tools.execute(name: "create_chore_proposal",
                              input: .object(["kind": .string("cover"), "occurrence_id": .string(occ.id.uuidString)]),
                              actor: "kristian", taskID: nil)
        #expect(r.isError == false)
        #expect(r.createdProposalID != nil)
        #expect(s.occurrence(occ.id)?.assigneeID == "kristian")
    }

    @Test func occupiedSlotReportsErrorText() {
        let s = makeStore()
        let tools = HouseTools(store: s)
        let r = tools.execute(name: "volunteer_to_cook",
                              input: .object(["date": .string(s.today.iso), "dish": .string("Pizza")]),
                              actor: "kristian", taskID: nil)
        #expect(r.isError == true)
        #expect(r.content.contains("Sam"))
    }

    @Test func unknownToolIsAnError() {
        let s = makeStore()
        let r = HouseTools(store: s).execute(name: "approve_as_sam", input: .object([:]), actor: "kristian", taskID: nil)
        #expect(r.isError == true)
    }

    @Test func mixedInvalidDatesDoNotPartiallyApply() {
        let store = HouseStore()
        let date = store.today
        let before = store.attendance(on: date)
        let result = HouseTools(store: store).execute(name: "set_my_attendance", input: .object([
            "dates": .array([.string(date.iso), .string("2026-02-31")]),
            "status": .string("away")
        ]), actor: "kristian", taskID: nil)
        #expect(result.isError)
        #expect(store.attendance(on: date) == before)
    }
}
