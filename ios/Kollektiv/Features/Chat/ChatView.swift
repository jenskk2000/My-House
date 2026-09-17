import SwiftUI

struct ChatView: View {
    @Environment(HouseStore.self) private var store
    @Environment(AgentRunner.self) private var runner
    @Environment(AppState.self) private var appState
    @State private var isSending = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    DemoPersonMenu(compact: true)
                    Spacer(minLength: 0)
                    VStack(spacing: 3) {
                        Text("House chat").font(Theme.title(22))
                        Text("\(store.members.count) housemates + House").font(Theme.caption)
                        if !runner.isConfigured {
                            Text("Agent not configured").font(Theme.caption)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.navy)
                    Spacer(minLength: 0)
                    HouseAvatar(size: 52)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Theme.butter)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(store.messages) { MessageRow(message: $0).id($0.id) }
                        }
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.messages.count) { _, _ in
                        if let last = store.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                composer
                    .onChange(of: appState.replyingToTaskID) { _, id in composerFocused = id != nil }
                    .onChange(of: store.currentMemberID) { _, _ in appState.replyingToTaskID = nil }

            }
            .background(Theme.cream.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0) }
            .background(Theme.butter.ignoresSafeArea(edges: .top))
        }
    }

    private var mentionsHouse: Bool { appState.mentionHouse || draftHasMentionToken }

    /// Case-sensitive whole-word "@House" so "@Housemates" and "@housewarming" do not match.
    private var draftHasMentionToken: Bool {
        appState.composerDraft.range(of: "(^|\\s)@House(\\b|$)", options: .regularExpression) != nil
    }

    private var composer: some View {
        @Bindable var appState = appState
        return VStack(spacing: 8) {
            if appState.replyingToTaskID != nil {
                HStack {
                    Text("Replying to House").font(Theme.caption)
                    Spacer()
                    Button("Cancel") { appState.replyingToTaskID = nil }
                }
            }
            if composerFocused {
                HStack { Spacer(); Button("Done") { composerFocused = false } }
            }
            if !mentionsHouse {
                HStack {
                    Button {
                        appState.composerDraft = "@House " + appState.composerDraft
                        appState.mentionHouse = true
                        composerFocused = true
                    } label: { Pill(text: "@House", color: .white, background: Theme.cobalt) }
                    Spacer()
                }
            }
            HStack(spacing: 10) {
                TextField("Message or @House", text: $appState.composerDraft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 18))
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)).foregroundStyle(Theme.cobalt)
                }
                .disabled(appState.composerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .accessibilityLabel("Send")
            }
        }
        .padding(12)
        .background(Theme.card)
    }

    private func send() async {
        let body = appState.composerDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let mentions = mentionsHouse
        appState.mentionHouse = false
        appState.composerDraft = ""
        isSending = true
        composerFocused = false
        if let taskID = appState.replyingToTaskID {
            appState.replyingToTaskID = nil
            await runner.answer(taskID: taskID, body: body, from: store.currentMemberID)
        } else {
            await runner.send(body: body, from: store.currentMemberID, mentionsHouse: mentions)
        }
        isSending = false
    }
}
