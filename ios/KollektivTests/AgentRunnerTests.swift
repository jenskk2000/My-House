import Foundation
import Testing
@testable import Kollektiv

/// Scripted client: returns responses in order and records requests.
final class FakeClient: AgentClient, @unchecked Sendable {
    var responses: [ClaudeResponse]
    var requests: [ClaudeRequest] = []
    var error: Error?
    /// If set, `error` is only thrown from this call number onwards (1-based). Nil = throw on every call.
    var errorAfter: Int?
    private var callCount = 0
    init(responses: [ClaudeResponse]) { self.responses = responses }
    func complete(_ request: ClaudeRequest) async throws -> ClaudeResponse {
        requests.append(request)
        callCount += 1
        if let error, callCount >= (errorAfter ?? 1) { throw error }
        return responses.removeFirst()
    }
}

func toolUseResponse(id: String, name: String, input: [String: JSONValue]) -> ClaudeResponse {
    .init(content: .array([.object(["type": .string("tool_use"), "id": .string(id), "name": .string(name), "input": .object(input)])]),
          stop_reason: "tool_use")
}
func textResponse(_ text: String) -> ClaudeResponse {
    .init(content: .array([.object(["type": .string("text"), "text": .string(text)])]), stop_reason: "end_turn")
}

@MainActor
@Suite struct AgentRunnerTests {
    static let fixedNow: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 14; c.hour = 10
        return LocalDate.calendar.date(from: c)!
    }()

    @Test func journeyAExecutesToolsAndWaitsForVolunteer() async throws {
        let s = HouseStore(now: { Self.fixedNow })
        let occ = s.occurrences.first { $0.name == "Kitchen" && $0.assigneeID == "kristian" }!
        let client = FakeClient(responses: [
            toolUseResponse(id: "t1", name: "set_my_attendance", input: ["dates": .array([.string("2026-09-18"), .string("2026-09-19"), .string("2026-09-20")]), "status": .string("away")]),
            toolUseResponse(id: "t2", name: "create_chore_proposal", input: ["kind": .string("cover"), "occurrence_id": .string(occ.id.uuidString)]),
            textResponse("Marked you away Fri 18 - Sun 20 Sep. Who can take the kitchen on Saturday 19 Sep?"),
        ])
        let runner = AgentRunner(store: s, client: client)
        let msg = s.postMessage(sender: .member("kristian"), body: "@House mark me away Fri-Sun and ask someone to take my Saturday kitchen clean", mentionsHouse: true)
        let task = s.createTask(initiator: "kristian", sourceMessageID: msg.id)

        await runner.run(taskID: task.id)

        #expect(s.task(task.id)?.state == .waitingForVolunteer)
        #expect(s.task(task.id)?.proposalID != nil)
        #expect(s.attendance(on: LocalDate(iso: "2026-09-19")!)["kristian"] == .away)
        #expect(s.occurrence(occ.id)?.assigneeID == "kristian")
        #expect(s.messages.last?.sender == .house)
        #expect(s.messages.last?.taskID == task.id)
        // the tool loop echoed the assistant turn and sent tool_result blocks
        #expect(client.requests.count == 3)
        #expect(client.requests[1].messages.count == 3)
        #expect(client.requests[1].messages[2].content["0"] == nil) // sanity: content is an array, not object
    }

    @Test func failureMarksTaskFailedWithoutFakeSuccess() async {
        let s = HouseStore(now: { Self.fixedNow })
        let client = FakeClient(responses: [])
        client.error = URLError(.notConnectedToInternet)
        let runner = AgentRunner(store: s, client: client)
        let msg = s.postMessage(sender: .member("kristian"), body: "@House hi", mentionsHouse: true)
        let task = s.createTask(initiator: "kristian", sourceMessageID: msg.id)
        await runner.run(taskID: task.id)
        guard case .failed = s.task(task.id)?.state else { Issue.record("expected failed"); return }
        #expect(s.messages.filter { $0.sender == .house }.isEmpty)
    }

    @Test func toolLoopIsCapped() async {
        let s = HouseStore(now: { Self.fixedNow })
        let loop = Array(repeating: toolUseResponse(id: "x", name: "read_house_context", input: [:]), count: 10)
        let client = FakeClient(responses: loop)
        let runner = AgentRunner(store: s, client: client)
        let msg = s.postMessage(sender: .member("kristian"), body: "@House loop", mentionsHouse: true)
        let task = s.createTask(initiator: "kristian", sourceMessageID: msg.id)
        await runner.run(taskID: task.id)
        #expect(client.requests.count <= 7)
        guard case .failed = s.task(task.id)?.state else { Issue.record("expected failed after cap"); return }
    }

    @Test func emptyReplyIsFailureNotSuccess() async {
        let s = HouseStore(now: { Self.fixedNow })
        let client = FakeClient(responses: [ClaudeResponse(content: .array([]), stop_reason: "max_tokens")])
        let runner = AgentRunner(store: s, client: client)
        let msg = s.postMessage(sender: .member("kristian"), body: "@House hi", mentionsHouse: true)
        let task = s.createTask(initiator: "kristian", sourceMessageID: msg.id)
        await runner.run(taskID: task.id)
        guard case .failed = s.task(task.id)?.state else { Issue.record("expected failed"); return }
        #expect(s.messages.filter { $0.sender == .house }.isEmpty)
    }

    @Test func failureAfterProposalKeepsProposalOnTask() async {
        let s = HouseStore(now: { Self.fixedNow })
        let occ = s.occurrences.first { $0.name == "Kitchen" && $0.assigneeID == "kristian" }!
        let client = FakeClient(responses: [
            toolUseResponse(id: "t1", name: "create_chore_proposal", input: ["kind": .string("cover"), "occurrence_id": .string(occ.id.uuidString)]),
        ])
        client.error = URLError(.timedOut)
        client.errorAfter = 2
        let runner = AgentRunner(store: s, client: client)
        let msg = s.postMessage(sender: .member("kristian"), body: "@House ask someone to take my Saturday kitchen clean", mentionsHouse: true)
        let task = s.createTask(initiator: "kristian", sourceMessageID: msg.id)

        await runner.run(taskID: task.id)

        guard case .failed(let reason) = s.task(task.id)?.state else { Issue.record("expected failed"); return }
        #expect(s.task(task.id)?.proposalID != nil)
        #expect(reason.contains("Already applied"))
        #expect(s.messages.filter { $0.sender == .house }.isEmpty)
    }
}
