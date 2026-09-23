import SwiftUI

enum Theme {
    static let accent = Color(red: 1.0, green: 0.275, blue: 0.333)
    static let ink = Color(red: 0.035, green: 0.035, blue: 0.07)
    static let inkRaised = Color(red: 0.08, green: 0.075, blue: 0.14)
    static let violet = Color(red: 0.47, green: 0.33, blue: 1.0)
    static let textDim = Color.white.opacity(0.62)
    static let textFaint = Color.white.opacity(0.38)

    static let cardRadius: CGFloat = 26
    static let chipRadius: CGFloat = 14
    static let gutter: CGFloat = 16

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }

    static func label(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .bold).width(.expanded)
    }

    static let price = Font.system(size: 17, weight: .heavy).monospacedDigit()

    static let fallbackTier = Color(white: 0.55)
    /// Items Riot sells that valorant-api.com hasn't published yet.
    static let newItem = Color(red: 0.95, green: 0.78, blue: 0.38)
    static let owned = Color(red: 0.36, green: 0.9, blue: 0.7)
}

extension Color {
    /// valorant-api.com tier colors are RRGGBBAA with a faint alpha meant for backgrounds; the alpha is dropped.
    init(rgbaHex hex: String) {
        let value = UInt64(hex.prefix(6), radix: 16) ?? 0x808080
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum CurrencyIcon {
    static func url(_ id: String) -> URL {
        URL(string: "https://media.valorant-api.com/currencies/\(id)/displayicon.png")!
    }
}
