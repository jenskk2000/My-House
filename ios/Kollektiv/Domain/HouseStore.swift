import Foundation
import Observation

@Observable
@MainActor
final class HouseStore {
    // MARK: Identity and clock
    let houseName = "Kollektiv"
    @ObservationIgnored let now: () -> Date
    var today: LocalDate { LocalDate(now()) }

    // MARK: State
    private(set) var members: [Member] = []
    var currentMemberID: MemberID = "kristian"
    var currentMember: Member { member(currentMemberID)! }

    private(set) var dinners: [Dinner] = []
    private(set) var attendanceByDate: [LocalDate: [MemberID: Attendance]] = [:]
    private(set) var choreTemplates: [ChoreTemplate] = []
    private(set) var occurrences: [ChoreOccurrence] = []
    private(set) var events: [HouseEvent] = []
    private(set) var messages: [Message] = []
    private(set) var tasks: [AgentTask] = []
    private(set) var proposals: [CoverProposal] = []

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
        seed()
    }

    // MARK: Lookups
    func member(_ id: MemberID) -> Member? { members.first { $0.id == id } }
    func dinner(on date: LocalDate) -> Dinner? { dinners.first { $0.date == date } }
    func attendance(on date: LocalDate) -> [MemberID: Attendance] { attendanceByDate[date] ?? [:] }
    func occurrence(_ id: UUID) -> ChoreOccurrence? { occurrences.first { $0.id == id } }
    func proposal(_ id: UUID) -> CoverProposal? { proposals.first { $0.id == id } }
    func task(_ id: UUID) -> AgentTask? { tasks.first { $0.id == id } }
    func openProposal(forOccurrence id: UUID) -> CoverProposal? {
        proposals.first { $0.occurrenceID == id && $0.state == .awaitingVolunteer }
    }

    private func requireMember(_ id: MemberID) throws -> Member {
        guard let m = member(id) else { throw DomainError.notAMember(id) }
        return m
    }

    // MARK: Commands (actor is always supplied by the app, never by the model)

    /// Changes only the actor's own attendance on future dates (today counts as future).
    /// Returns the dates that were changed. Throws if none are in the future.
    @discardableResult
    func setAttendance(actor: MemberID, dates: [LocalDate], status: Attendance) throws -> [LocalDate] {
        _ = try requireMember(actor)
        let future = dates.filter { $0 >= today }.sorted()
        guard !future.isEmpty else { throw DomainError.noFutureDates }
        for d in future {
            ensureDinner(on: d)
            var row = attendanceByDate[d] ?? [:]
            row[actor] = status
            attendanceByDate[d] = row
        }
        return future
    }

    /// Claims a free cooking slot for the actor. Never overwrites another cook.
    @discardableResult
    func volunteerToCook(actor: MemberID, date: LocalDate, dish: String, time: String?) throws -> Dinner {
        _ = try requireMember(actor)
        guard date >= today else { throw DomainError.dateInPast(date) }
        ensureDinner(on: date)
        let idx = dinners.firstIndex { $0.date == date }!
        if let existing = dinners[idx].cookID, existing != actor {
            throw DomainError.slotTaken(cook: member(existing)?.displayName ?? existing)
        }
        dinners[idx].cookID = actor
        dinners[idx].dish = dish
        if let time { dinners[idx].time = time }
        dinners[idx].revision += 1
        return dinners[idx]
    }

    /// Creates an open cover request for one of the actor's own, uncompleted occurrences.
    @discardableResult
    func createCoverProposal(actor: MemberID, occurrenceID: UUID, taskID: UUID?) throws -> CoverProposal {
        _ = try requireMember(actor)
        guard let occ = occurrence(occurrenceID) else { throw DomainError.occurrenceNotFound }
        guard occ.assigneeID == actor else { throw DomainError.notYourRecord }
        guard !occ.isCompleted else { throw DomainError.occurrenceCompleted }
        guard openProposal(forOccurrence: occurrenceID) == nil else { throw DomainError.alreadyProposed }
        let p = CoverProposal(
            id: UUID(), taskID: taskID, occurrenceID: occurrenceID, initiatorID: actor,
            expectedOccurrenceRevision: occ.revision, revision: 1,
            state: .awaitingVolunteer, acceptedByID: nil, createdAt: now()
        )
        proposals.append(p)
        return p
    }

    /// Deterministic acceptance. First successful acceptance wins; the occurrence must be unchanged.
    @discardableResult
    func acceptCover(actor: MemberID, proposalID: UUID, expectedRevision: Int) throws -> ChoreOccurrence {
        _ = try requireMember(actor)
        guard let pIdx = proposals.firstIndex(where: { $0.id == proposalID }) else { throw DomainError.proposalNotFound }
        let p = proposals[pIdx]
        guard p.state == .awaitingVolunteer else { throw DomainError.alreadyResolved }
        guard p.revision == expectedRevision else { throw DomainError.staleRevision }
        guard p.initiatorID != actor else { throw DomainError.cannotAcceptOwnRequest }
        guard let oIdx = occurrences.firstIndex(where: { $0.id == p.occurrenceID }) else { throw DomainError.occurrenceNotFound }
        guard occurrences[oIdx].revision == p.expectedOccurrenceRevision,
              occurrences[oIdx].assigneeID == p.initiatorID,
              !occurrences[oIdx].isCompleted else { throw DomainError.staleRevision }
        // single "transaction": both writes happen together on the main actor
        occurrences[oIdx].assigneeID = actor
        occurrences[oIdx].revision += 1
        proposals[pIdx].state = .applied
        proposals[pIdx].acceptedByID = actor
        proposals[pIdx].revision += 1
        return occurrences[oIdx]
    }

    func cancelCover(actor: MemberID, proposalID: UUID) throws {
        _ = try requireMember(actor)
        guard let pIdx = proposals.firstIndex(where: { $0.id == proposalID }) else { throw DomainError.proposalNotFound }
        guard proposals[pIdx].initiatorID == actor else { throw DomainError.notYourRecord }
        guard proposals[pIdx].state == .awaitingVolunteer else { throw DomainError.alreadyResolved }
        proposals[pIdx].state = .cancelled
        proposals[pIdx].revision += 1
    }

    func completeChore(actor: MemberID, occurrenceID: UUID) throws {
        _ = try requireMember(actor)
        guard let idx = occurrences.firstIndex(where: { $0.id == occurrenceID }) else { throw DomainError.occurrenceNotFound }
        guard occurrences[idx].assigneeID == actor else { throw DomainError.notYourRecord }
        guard !occurrences[idx].isCompleted else { throw DomainError.occurrenceCompleted }
        occurrences[idx].completedByID = actor
        occurrences[idx].revision += 1
    }

    // MARK: Chat and tasks

    @discardableResult
    func postMessage(sender: Sender, body: String, mentionsHouse: Bool = false, taskID: UUID? = nil) -> Message {
        let m = Message(id: UUID(), sender: sender, body: body, mentionsHouse: mentionsHouse, sentAt: now(), taskID: taskID)
        messages.append(m)
        return m
    }

    @discardableResult
    func createTask(initiator: MemberID, sourceMessageID: UUID) -> AgentTask {
        let t = AgentTask(id: UUID(), initiatorID: initiator, sourceMessageID: sourceMessageID, state: .working, proposalID: nil, attempts: 0)
        tasks.append(t)
        if let mIdx = messages.firstIndex(where: { $0.id == sourceMessageID }) { messages[mIdx].taskID = t.id }
        return t
    }

    func updateTask(_ id: UUID, _ mutate: (inout AgentTask) -> Void) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        mutate(&tasks[idx])
    }

    // MARK: Internal helpers used by seed and commands

    func ensureDinner(on date: LocalDate) {
        if dinner(on: date) == nil {
            dinners.append(Dinner(id: UUID(), date: date, dish: nil, cookID: nil, time: nil, revision: 0))
            dinners.sort { $0.date < $1.date }
        }
    }

    func _seedSet(members: [Member], dinners: [Dinner], attendance: [LocalDate: [MemberID: Attendance]],
                  templates: [ChoreTemplate], occurrences: [ChoreOccurrence], events: [HouseEvent], messages: [Message]) {
        self.members = members
        self.dinners = dinners.sorted { $0.date < $1.date }
        self.attendanceByDate = attendance
        self.choreTemplates = templates
        self.occurrences = occurrences.sorted { $0.date < $1.date }
        self.events = events
        self.messages = messages
    }
}
