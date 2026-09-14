import SwiftUI

struct MessageRow: View {
    @Environment(HouseStore.self) private var store
    let message: Message

    private var isMe: Bool { message.sender == .member(store.currentMemberID) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isMe { Spacer(minLength: 40) } else { avatar }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(senderName).font(Theme.caption.bold()).foregroundStyle(.secondary)
                bubble
                if let taskID = message.taskID { TaskCardView(taskID: taskID, anchoredTo: message) }
            }
            if isMe { avatar } else { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 16)
    }

    private var senderName: String {
        switch message.sender {
        case .house: return "House"
        case .member(let id): return isMe ? "You" : (store.member(id)?.displayName ?? id)
        }
    }

    @ViewBuilder private var avatar: some View {
        switch message.sender {
        case .house: HouseAvatar(size: 36)
        case .member(let id): if let m = store.member(id) { MemberAvatar(member: m) }
        }
    }

    private var bubble: some View {
        Text(attributedBody)
            .font(Theme.body)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(isMe ? .white : Theme.navy)
    }

    private var bubbleColor: Color {
        switch message.sender {
        case .house: return Theme.cream
        case .member: return isMe ? Theme.cobalt : Color(white: 0.93)
        }
    }

    /// Bolds the @House mention.
    private var attributedBody: AttributedString {
        var s = AttributedString(message.body)
        if let range = s.range(of: "@House") { s[range].font = Theme.body.bold() }
        return s
    }
}
