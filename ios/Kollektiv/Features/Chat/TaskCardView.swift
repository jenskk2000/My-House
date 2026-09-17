import SwiftUI

/// Renders the state of an agent task. Shown under the source message while working/failed,
/// and under the House reply once a proposal exists.
struct TaskCardView: View {
    @Environment(HouseStore.self) private var store
    @Environment(AgentRunner.self) private var runner
    @Environment(AppState.self) private var appState
    let taskID: UUID
    let anchoredTo: Message
    @State private var errorText: String?

    private var task: AgentTask? { store.task(taskID) }
    private var proposal: CoverProposal? { task?.proposalID.flatMap { store.proposal($0) } }
    private var isSourceMessage: Bool { anchoredTo.id == task?.sourceMessageID }

    var body: some View {
        if let task {
            // Working/failed state hangs off the human message; results hang off the House reply.
            if isSourceMessage {
                switch task.state {
                case .working: statusLine("House is working…", "hourglass", Theme.navy)
                case .failed(let reason):
                    VStack(alignment: .leading, spacing: 8) {
                        statusLine("House couldn't finish this", "exclamationmark.triangle.fill", Theme.coral)
                        Text(reason).font(Theme.caption).foregroundStyle(.secondary)
                        Button("Retry") { Task { await runner.retry(taskID: taskID) } }
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .buttonStyle(.borderedProminent).tint(Theme.cobalt)
                        // A cover request created before the failure can still be accepted.
                        if let proposal, let occ = store.occurrence(proposal.occurrenceID) {
                            coverCard(proposal, occ)
                        }
                    }
                    .padding(12).background(Theme.cream, in: RoundedRectangle(cornerRadius: 14))
                default: EmptyView()
                }
            } else if case .needsInput = task.state, task.initiatorID == store.currentMemberID {
                Button("Reply to House") {
                    appState.replyingToTaskID = task.id
                    appState.selectedTab = .chat
                }
                .buttonStyle(.borderedProminent).tint(Theme.cobalt)
            } else if let proposal, let occ = store.occurrence(proposal.occurrenceID) {
                coverCard(proposal, occ)
            } else if task.state == .completed {
                statusLine("Completed", "checkmark.circle.fill", Theme.teal)
            }
        }
    }

    private func statusLine(_ text: String, _ icon: String, _ color: Color) -> some View {
        Label(text, systemImage: icon).font(Theme.caption.bold()).foregroundStyle(color)
    }

    private func coverCard(_ p: CoverProposal, _ occ: ChoreOccurrence) -> some View {
        let me = store.currentMemberID
        let assignee = occ.assigneeID.flatMap { store.member($0) }?.displayName ?? "unassigned"
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image("chores").resizable().scaledToFit().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(occ.name) · \(occ.date.longLabel)").font(Theme.body.bold()).fixedSize(horizontal: false, vertical: true)
                    Text("Currently: \(assignee)").font(Theme.caption).foregroundStyle(.secondary)
                }
            }
            switch p.state {
            case .awaitingVolunteer:
                if p.initiatorID == me {
                    statusLine("Waiting for a volunteer", "hand.raised", Theme.navy)
                    Button("Cancel request") {
                        do { try store.cancelCover(actor: me, proposalID: p.id); errorText = nil }
                        catch { errorText = error.localizedDescription }
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .buttonStyle(.bordered).tint(Theme.coral)
                } else {
                    PrimaryButton(title: "I can take it", systemImage: "hand.raised.fill") {
                        do {
                            let updated = try store.acceptCover(actor: me, proposalID: p.id, expectedRevision: p.revision)
                            let who = store.member(me)?.displayName ?? me
                            store.postMessage(sender: .house, body: "\(updated.name) on \(updated.date.longLabel) → \(who). Chore schedule updated.")
                            store.updateTask(taskID) { $0.state = .completed }
                            errorText = nil
                        } catch { errorText = error.localizedDescription }
                    }
                }
            case .applied:
                statusLine("Taken by \(p.acceptedByID.flatMap { store.member($0) }?.displayName ?? "someone")", "checkmark.circle.fill", Theme.teal)
            case .cancelled:
                statusLine("Request cancelled", "xmark.circle", .secondary)
            }
            if let errorText { Text(errorText).font(Theme.caption).foregroundStyle(Theme.coral) }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.navy.opacity(0.08)))
        .frame(maxWidth: 300)
    }
}
