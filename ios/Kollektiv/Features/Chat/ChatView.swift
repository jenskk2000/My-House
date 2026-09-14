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
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(store.messages) { MessageRow(message: $0).id($0.id) }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: store.messages.count) { _, _ in
                        if let last = store.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                composer
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("House chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ChatDemoPersonMenu() }
                ToolbarItem(placement: .topBarTrailing) {
                    if !runner.isConfigured {
                        Label("No API key", systemImage: "key.slash").font(Theme.caption).foregroundStyle(Theme.coral)
                    }
                }
            }
            .toolbarBackground(Theme.butter, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var mentionsHouse: Bool { appState.composerDraft.localizedCaseInsensitiveContains("@House") }

    private var composer: some View {
        @Bindable var appState = appState
        return VStack(spacing: 8) {
            if !mentionsHouse {
                HStack {
                    Button {
                        appState.composerDraft = "@House " + appState.composerDraft
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
                    .background(Color(white: 0.95), in: RoundedRectangle(cornerRadius: 18))
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)).foregroundStyle(Theme.cobalt)
                }
                .disabled(appState.composerDraft.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                .accessibilityLabel("Send")
            }
        }
        .padding(12)
        .background(.white)
    }

    private func send() async {
        let body = appState.composerDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let mentions = mentionsHouse
        appState.composerDraft = ""
        isSending = true
        await runner.send(body: body, from: store.currentMemberID, mentionsHouse: mentions)
        isSending = false
    }
}
