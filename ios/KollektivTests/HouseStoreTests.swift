import Foundation
import Testing
@testable import Kollektiv

@MainActor
@Suite struct HouseStoreTests {
    /// Monday 14 Sep 2026, 10:00 Oslo.
    static let fixedNow: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 14; c.hour = 10
        return LocalDate.calendar.date(from: c)!
    }()

    func makeStore() -> HouseStore { HouseStore(now: { Self.fixedNow }) }

    @Test func seedIsRelativeToToday() {
        let s = makeStore()
        #expect(s.today == LocalDate(year: 2026, month: 9, day: 14))
        #expect(s.dinner(on: s.today)?.cookID == "sam")
        // the upcoming Saturday kitchen is Kristian's (Journey A precondition)
        let sat = s.occurrences.first { $0.name == "Kitchen" && $0.date == LocalDate(year: 2026, month: 9, day: 19) }
        #expect(sat?.assigneeID == "kristian")
    }

    // A01
    @Test func attendanceChangesOnlySendersDates() throws {
        let s = makeStore()
        let fri = LocalDate(year: 2026, month: 9, day: 18)
        let sat = fri.adding(days: 1), sun = fri.adding(days: 2)
        let changed = try s.setAttendance(actor: "kristian", dates: [fri, sat, sun], status: .away)
        #expect(changed == [fri, sat, sun])
        #expect(s.attendance(on: sat)["kristian"] == .away)
        #expect(s.attendance(on: sat)["sam"] == nil || s.attendance(on: sat)["sam"] == .unknown)
        #expect(s.attendance(on: s.today)["kristian"] == .eating) // untouched
    }

    @Test func attendanceRejectsPastDatesAndUnknownActor() {
        let s = makeStore()
        #expect(throws: DomainError.noFutureDates) {
            try s.setAttendance(actor: "kristian", dates: [s.today.adding(days: -1)], status: .away)
        }
        #expect(throws: DomainError.notAMember("eve")) {
            try s.setAttendance(actor: "eve", dates: [s.today.adding(days: 1)], status: .away)
        }
    }

    // A05
    @Test func claimFreeSlotOnce() throws {
        let s = makeStore()
        let thu = LocalDate(year: 2026, month: 9, day: 17)
        let d = try s.volunteerToCook(actor: "kristian", date: thu, dish: "Vegetable curry", time: nil)
        #expect(d.cookID == "kristian")
        #expect(d.dish == "Vegetable curry")
        #expect(d.revision == 1)
    }

    // A06
    @Test func occupiedSlotIsPreserved() {
        let s = makeStore()
        #expect(throws: DomainError.slotTaken(cook: "Sam")) {
            try s.volunteerToCook(actor: "kristian", date: s.today, dish: "Pizza", time: nil)
        }
        #expect(s.dinner(on: s.today)?.cookID == "sam")
    }

    // A07 + A08
    @Test func coverStaysAssignedUntilAcceptedAndOnlyOneWins() throws {
        let s = makeStore()
        let sat = LocalDate(year: 2026, month: 9, day: 19)
        let occ = s.occurrences.first { $0.name == "Kitchen" && $0.date == sat }!
        let p = try s.createCoverProposal(actor: "kristian", occurrenceID: occ.id, taskID: nil)
        #expect(s.occurrence(occ.id)?.assigneeID == "kristian")          // A07
        #expect(throws: DomainError.cannotAcceptOwnRequest) {
            try s.acceptCover(actor: "kristian", proposalID: p.id, expectedRevision: p.revision)
        }
        let after = try s.acceptCover(actor: "sam", proposalID: p.id, expectedRevision: p.revision)
        #expect(after.assigneeID == "sam")
        #expect(s.proposal(p.id)?.state == .applied)
        #expect(throws: DomainError.alreadyResolved) {                     // A08
            try s.acceptCover(actor: "mia", proposalID: p.id, expectedRevision: p.revision)
        }
        #expect(s.occurrence(occ.id)?.assigneeID == "sam")
    }

    @Test func cannotProposeSomeoneElsesChore() {
        let s = makeStore()
        let sunBath = s.occurrences.first { $0.name == "Bathroom" && $0.assigneeID == "sam" }!
        #expect(throws: DomainError.notYourRecord) {
            try s.createCoverProposal(actor: "kristian", occurrenceID: sunBath.id, taskID: nil)
        }
    }

    @Test func completeOwnChoreOnly() throws {
        let s = makeStore()
        let mine = s.occurrences.first { $0.assigneeID == "kristian" }!
        #expect(throws: DomainError.notYourRecord) { try s.completeChore(actor: "sam", occurrenceID: mine.id) }
        try s.completeChore(actor: "kristian", occurrenceID: mine.id)
        #expect(s.occurrence(mine.id)?.isCompleted == true)
    }

    @Test func attendanceSplitSeparatesUnknown() throws {
        let s = makeStore()
        let split = s.attendanceSplit(on: s.today)
        #expect(split.eating.map(\.id) == ["kristian", "sam"])
        #expect(split.unknown.map(\.id) == ["mia"])
    }
}
