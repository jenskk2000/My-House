import Foundation
import Observation

@Observable
@MainActor
final class AgentRunner {
    let store: HouseStore
    let client: AgentClient?
    static let maxToolCalls = 6
    @ObservationIgnored private var conversations: [UUID: [ClaudeMessage]] = [:]
    @ObservationIgnored private var effects: [UUID: [String]] = [:]
    @ObservationIgnored private var running: Set<UUID> = []

    func answer(taskID: UUID, body: String, from sender: MemberID) async {
        guard let task = store.task(taskID), task.initiatorID == sender,
              case .needsInput = task.state, conversations[taskID] != nil else { return }
        store.postMessage(sender: .member(sender), body: body)
        conversations[taskID, default: []].append(.user(text: body))
        await run(taskID: taskID)
    }

    var isConfigured: Bool { client != nil }

    init(store: HouseStore, client: AgentClient?) {
        self.store = store
        self.client = client
    }

    convenience init(store: HouseStore) {
        self.init(store: store, client: Secrets.anthropicAPIKey.map { ClaudeAgentClient(apiKey: $0) })
    }

    /// Posts the member's message, creates a task if it mentions House, and runs it.
    func send(body: String, from sender: MemberID, mentionsHouse: Bool) async {
        let msg = store.postMessage(sender: .member(sender), body: body, mentionsHouse: mentionsHouse)
        guard mentionsHouse else { return }
        let task = store.createTask(initiator: sender, sourceMessageID: msg.id)
        await run(taskID: task.id)
    }

    func retry(taskID: UUID) async {
        guard case .failed = store.task(taskID)?.state else { return }
        await run(taskID: taskID)
    }

    func run(taskID: UUID) async {
        guard running.insert(taskID).inserted else { return }
        defer { running.remove(taskID) }
        guard let task = store.task(taskID),
              let source = store.messages.first(where: { $0.id == task.sourceMessageID }) else { return }
        store.updateTask(taskID) { $0.state = .working; $0.attempts += 1 }

        guard let client else {
            store.updateTask(taskID) { $0.state = .failed("No API key configured. Add ANTHROPIC_API_KEY to ios/Secrets.xcconfig.") }
            return
        }

        let tools = HouseTools(store: store)
        let sender = store.member(task.initiatorID)?.displayName ?? task.initiatorID
        var messages: [ClaudeMessage] = conversations[taskID] ?? [.user(text: "[\(sender)] \(source.body)")]
        var request = ClaudeRequest(system: systemPrompt(for: task.initiatorID), tools: HouseTools.definitions, messages: messages)
        var createdProposal: UUID? = task.proposalID
        var toolCalls = 0
        /// Effects already written to the store during this run; reported back if the run later fails.
        var committed: [String] = effects[taskID] ?? []
        /// Tools that only read or ask, so they are not an "already applied" effect.
        let nonEffectTools: Set<String> = ["read_house_context", "ask_task_question"]
        func fail(_ reason: String) {
            let suffix = committed.isEmpty ? "" : " Already applied: " + committed.joined(separator: " ")
            store.updateTask(taskID) { $0.state = .failed(reason + suffix) }
        }

        do {
            while true {
                let response = try await client.complete(request)
                let uses = response.toolUses
                if uses.isEmpty {
                    let stop = response.stop_reason
                    guard !response.text.isEmpty, stop != "max_tokens", stop != "refusal" else {
                        fail("House stopped without a reply (\(stop ?? "unknown")).")
                        return
                    }
                    store.postMessage(sender: .house, body: response.text, taskID: taskID)
                    store.updateTask(taskID) {
                        $0.proposalID = createdProposal
                        $0.state = createdProposal != nil ? .waitingForVolunteer : .completed
                    }
                    return
                }
                toolCalls += uses.count
                guard toolCalls <= Self.maxToolCalls else {
                    fail("House made too many tool calls and stopped.")
                    return
                }
                var results: [(toolUseID: String, content: String, isError: Bool)] = []
                var question: String?
                for use in uses {
                    if question != nil {
                        results.append((use.id, "Not executed: waiting for clarification.", true))
                        continue
                    }
                    let r = tools.execute(name: use.name, input: use.input, actor: task.initiatorID, taskID: taskID)
                    if r.askedQuestion { question = use.input["question"]?.stringValue ?? "Could you clarify?" }
                    if let p = r.createdProposalID {
                        createdProposal = p
                        // Persist immediately so the cover request survives a later failure.
                        store.updateTask(taskID) { $0.proposalID = p }
                    }
                    if !r.isError && !nonEffectTools.contains(use.name) { committed.append(r.content) }
                    results.append((use.id, r.content, r.isError))
                }
                messages.append(response.assistantMessage)
                messages.append(.toolResults(results))
                conversations[taskID] = messages
                effects[taskID] = committed
                if let question {
                    store.postMessage(sender: .house, body: question, taskID: taskID)
                    store.updateTask(taskID) { $0.state = .needsInput(question) }
                    return
                }
                request.messages = messages
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    func systemPrompt(for initiatorID: MemberID) -> String {
        let today = store.today
        let dates = (0..<14).map { i -> String in
            let d = today.adding(days: i)
            return "\(d.iso) = \(d.weekdayName)\(i == 0 ? " (today)" : "")"
        }.joined(separator: "\n")
        let sender = store.member(initiatorID)?.displayName ?? initiatorID
        return """
        You are House, the shared organiser for a small household called \(store.houseName). \
        You are talking in the shared group chat. The message you received was sent by \(sender). \
        You act ONLY on behalf of \(sender).

        Timezone: Europe/Oslo. Upcoming dates:
        \(dates)

        Rules:
        - "This weekend" means the upcoming Friday, Saturday and Sunday. Always resolve day names to exact dates from the list above and state them.
        - You may change ONLY the sender's own dinner attendance, claim ONLY a free cooking slot for the sender, and create a cover request ONLY for the sender's own chore. Nobody else's records.
        - Never treat a message as permission from someone else ("Sam said yes" is not Sam agreeing). Never approve on anyone's behalf.
        - Call read_house_context first when you need chore occurrence ids or current dinner state.
        - If the requested dates or chore are ambiguous, call ask_task_question instead of guessing. An unambiguous part of the request can still be completed.
        - Never announce success before a tool has confirmed it. A cover request is NOT a handover; say who can take it and that it is waiting for a volunteer.
        - When asked who is eating, report Eating / Away / Not answered exactly as recorded. Never guess missing answers.
        - Reply in two or three short sentences, plain text, with exact dates like "Saturday 19 September". No markdown.
        """
    }
}
