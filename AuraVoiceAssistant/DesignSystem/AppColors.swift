import SwiftUI

enum AppColors {
    static let surface = Color(hex: 0xF8F9FF)
    static let surfaceContainerLowest = Color.white
    static let surfaceContainerLow = Color(hex: 0xEFF4FF)
    static let surfaceContainer = Color(hex: 0xE5EEFF)
    static let surfaceContainerHigh = Color(hex: 0xDCE9FF)
    static let surfaceContainerHighest = Color(hex: 0xD3E4FE)
    static let onSurface = Color(hex: 0x0B1C30)
    static let onSurfaceVariant = Color(hex: 0x464554)
    static let outline = Color(hex: 0x767586)
    static let primary = Color(hex: 0x4648D4)
    static let primaryContainer = Color(hex: 0x6063EE)
    static let primaryFixed = Color(hex: 0xE1E0FF)
    static let secondary = Color(hex: 0x0058BE)
    static let secondaryContainer = Color(hex: 0x2170E4)
    static let tertiary = Color(hex: 0x575C65)
    static let error = Color(hex: 0xBA1A1A)
    static let errorContainer = Color(hex: 0xFFDAD6)
    static let success = Color(hex: 0x16A34A)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
