import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = Theme.cobalt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct Pill: View {
    let text: String
    var color: Color = Theme.navy
    var background: Color = Theme.cream
    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(background, in: Capsule())
    }
}

/// Coloured circle with the member's initial. Colour is stable per member.
struct MemberAvatar: View {
    let member: Member
    var size: CGFloat = 36
    var body: some View {
        Text(member.initial)
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(member.color, in: Circle())
            .accessibilityLabel(member.displayName)
    }
}

struct HouseAvatar: View {
    var size: CGFloat = 36
    var body: some View {
        Image("agent")
            .resizable().scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("House")
    }
}
