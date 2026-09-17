import Foundation

struct ToolExecutionResult {
    let content: String
    let isError: Bool
    var createdProposalID: UUID? = nil
    var askedQuestion: Bool = false
}

@MainActor
struct HouseTools {
    let store: HouseStore

    static let definitions: [ToolDefinition] = [
        ToolDefinition(
            name: "read_house_context",
            description: "Read dinners, attendance, chore occurrences (with ids and assignees) and events for a date range in this house. Call this before changing anything you have not already seen.",
            input_schema: .object([
                "type": .string("object"),
                "properties": .object([
                    "from": .object(["type": .string("string"), "description": .string("Start date YYYY-MM-DD. Defaults to today.")]),
                    "to": .object(["type": .string("string"), "description": .string("End date YYYY-MM-DD inclusive. Defaults to 13 days after from.")])
                ]),
                "required": .array([])
            ])),
        ToolDefinition(
            name: "set_my_attendance",
            description: "Set the requesting member's OWN dinner attendance on specific future dates. Only affects the sender. Use exact YYYY-MM-DD dates.",
            input_schema: .object([
                "type": .string("object"),
                "properties": .object([
                    "dates": .object(["type": .string("array"), "items": .object(["type": .string("string")]), "description": .string("Dates YYYY-MM-DD")]),
                    "status": .object(["type": .string("string"), "enum": .array([.string("eating"), .string("away"), .string("unknown")])])
                ]),
                "required": .array([.string("dates"), .string("status")])
            ])),
        ToolDefinition(
            name: "volunteer_to_cook",
            description: "Claim a FREE cooking slot for the requesting member on one date with a dish. Fails if someone else is already cooking; never overwrite another cook.",
            input_schema: .object([
                "type": .string("object"),
                "properties": .object([
                    "date": .object(["type": .string("string"), "description": .string("YYYY-MM-DD")]),
                    "dish": .object(["type": .string("string")]),
                    "time": .object(["type": .string("string"), "description": .string("Optional HH:MM")])
                ]),
                "required": .array([.string("date"), .string("dish")])
            ])),
        ToolDefinition(
            name: "create_chore_proposal",
            description: "Create an open cover request for ONE of the requesting member's own chore occurrences, so another housemate can volunteer to take it. Use the occurrence id from read_house_context. The chore stays assigned to the sender until someone accepts.",
            input_schema: .object([
                "type": .string("object"),
                "properties": .object([
                    "kind": .object(["type": .string("string"), "enum": .array([.string("cover")])]),
                    "occurrence_id": .object(["type": .string("string"), "description": .string("UUID of the sender's chore occurrence")])
                ]),
                "required": .array([.string("kind"), .string("occurrence_id")])
            ])),
        ToolDefinition(
            name: "ask_task_question",
            description: "Ask the sender ONE focused clarification when the request is ambiguous (which dates, which chore). Do not change anything ambiguous before asking.",
            input_schema: .object([
                "type": .string("object"),
                "properties": .object([
                    "question": .object(["type": .string("string")]),
                    "choices": .object(["type": .string("array"), "items": .object(["type": .string("string")])])
                ]),
                "required": .array([.string("question")])
            ])),
    ]

    /// Executes a tool call. `actor` is always the authenticated sender supplied by the app;
    /// any member/actor fields in `input` are ignored (acceptance A15).
    func execute(name: String, input: JSONValue, actor: MemberID, taskID: UUID?) -> ToolExecutionResult {
        do {
            switch name {
            case "read_house_context":
                let from = input["from"]?.stringValue.flatMap(LocalDate.init(iso:)) ?? store.today
                let to = input["to"]?.stringValue.flatMap(LocalDate.init(iso:)) ?? from.adding(days: 13)
                return .init(content: store.contextText(from: from, to: to), isError: false)

            case "set_my_attendance":
                let rawDates = input["dates"]?.arrayValue ?? []
                let dates = rawDates.compactMap { $0.stringValue }.compactMap(LocalDate.init(iso:))
                guard dates.count == rawDates.count else {
                    return .init(content: "Every date must be a valid YYYY-MM-DD calendar date. Nothing changed.", isError: true)
                }
                guard let statusRaw = input["status"]?.stringValue, let status = Attendance(rawValue: statusRaw) else {
                    return .init(content: "status must be eating, away or unknown", isError: true)
                }
                guard !dates.isEmpty else { return .init(content: "dates must contain at least one YYYY-MM-DD date", isError: true) }
                let changed = try store.setAttendance(actor: actor, dates: dates, status: status)
                let who = store.member(actor)?.displayName ?? actor
                return .init(content: "\(who) is now \(status.label.lowercased()) on: " + changed.map(\.longLabel).joined(separator: ", "), isError: false)

            case "volunteer_to_cook":
                guard let date = input["date"]?.stringValue.flatMap(LocalDate.init(iso:)) else {
                    return .init(content: "date must be YYYY-MM-DD", isError: true)
                }
                guard let dish = input["dish"]?.stringValue, !dish.isEmpty else { return .init(content: "dish is required", isError: true) }
                let d = try store.volunteerToCook(actor: actor, date: date, dish: dish, time: input["time"]?.stringValue)
                let who = store.member(actor)?.displayName ?? actor
                return .init(content: "\(who) is cooking \(d.dish ?? dish) on \(d.date.longLabel)\(d.time.map { " at \($0)" } ?? "").", isError: false)

            case "create_chore_proposal":
                guard let idString = input["occurrence_id"]?.stringValue, let occID = UUID(uuidString: idString) else {
                    return .init(content: "occurrence_id must be a UUID from read_house_context", isError: true)
                }
                let p = try store.createCoverProposal(actor: actor, occurrenceID: occID, taskID: taskID)
                let occ = store.occurrence(occID)!
                return .init(content: "Cover request created for \(occ.name) on \(occ.date.longLabel). It stays assigned to the sender until a housemate taps 'I can take it'. Do not claim it is handed over yet.",
                             isError: false, createdProposalID: p.id)

            case "ask_task_question":
                let q = input["question"]?.stringValue ?? "Could you clarify?"
                return .init(content: "Question recorded: \(q). End your turn now and wait for the sender's reply.", isError: false, askedQuestion: true)

            default:
                return .init(content: "Unknown tool \(name). Only the provided tools are available.", isError: true)
            }
        } catch let e as DomainError {
            return .init(content: e.errorDescription ?? "\(e)", isError: true)
        } catch {
            return .init(content: error.localizedDescription, isError: true)
        }
    }
}
