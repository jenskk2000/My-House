import SwiftUI

enum Theme {
    static let cobalt = Color(hex: 0x0755F5)
    static let butter = Color(hex: 0xFFF08A)
    static let coral  = Color(hex: 0xFF765B)
    static let teal   = Color(hex: 0x28B99E)
    static let cream  = Color(hex: 0xFFFCF2)
    static let navy   = Color(hex: 0x07112F)

    static func heading(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static let body: Font = .system(.body, design: .rounded)
    static let caption: Font = .system(.caption, design: .rounded)
    static let cornerRadius: CGFloat = 20
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
