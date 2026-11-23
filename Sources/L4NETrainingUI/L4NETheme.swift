import SwiftUI

/// L4NE Performance Brand Design System
/// Aesthetic: Dark Carbon / Anthracite background, crisp white typography,
/// Electric Lime (`#CCFF00`) primary accent, and geometric Lane 4 pool motif.
public enum L4NETheme {
    /// Deep Pool Carbon background (`#0A0C0E`)
    public static let background = Color(red: 0.039, green: 0.047, blue: 0.055)
    /// Elevated Anthracite Card surface (`#12161B`)
    public static let cardSurface = Color(red: 0.071, green: 0.086, blue: 0.106)
    /// Secondary Muted surface (`#1A2028`)
    public static let mutedSurface = Color(red: 0.102, green: 0.125, blue: 0.157)
    /// Subtle structural border (`#262E38`)
    public static let border = Color(red: 0.149, green: 0.180, blue: 0.220)

    /// Signature L4NE Electric Lime accent (`#CCFF00`)
    public static let electricLime = Color(red: 0.800, green: 1.000, blue: 0.000)
    /// Personal Best / Positive Improvement Signal Green (`#22C55E`)
    public static let signalGreen = Color(red: 0.133, green: 0.773, blue: 0.369)
    /// Fatigue / Protocol Warning Amber (`#F59E0B`)
    public static let warningAmber = Color(red: 0.961, green: 0.620, blue: 0.043)
    /// Regression / Destructive Red (`#EF4444`)
    public static let regressionRed = Color(red: 0.937, green: 0.267, blue: 0.267)

    /// Crisp Pure White text (`#F8FAFC`)
    public static let textPrimary = Color(red: 0.973, green: 0.980, blue: 0.988)
    /// Metallic Silver secondary text (`#94A3B8`)
    public static let textSecondary = Color(red: 0.580, green: 0.639, blue: 0.722)
}

/// Stylized `L4NE` brand header where the digit `4` is highlighted in Electric Lime (`#CCFF00`)
/// and accompanied by a minimal geometric swimming lane icon.
public struct L4NEBrandWordmark: View {
    public let subtitle: String

    public init(subtitle: String = "PERFORMANCE") {
        self.subtitle = subtitle
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Minimal geometric Swimming Lane 4 emblem
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(L4NETheme.cardSurface)
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(L4NETheme.electricLime.opacity(0.6), lineWidth: 1.5)
                    )

                HStack(spacing: 3) {
                    Rectangle()
                        .fill(L4NETheme.textSecondary.opacity(0.35))
                        .frame(width: 2, height: 20)
                    Rectangle()
                        .fill(L4NETheme.electricLime)
                        .frame(width: 4, height: 22)
                    Rectangle()
                        .fill(L4NETheme.textSecondary.opacity(0.35))
                        .frame(width: 2, height: 20)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 0) {
                    Text("L")
                        .foregroundStyle(L4NETheme.textPrimary)
                    Text("4")
                        .foregroundStyle(L4NETheme.electricLime)
                    Text("NE")
                        .foregroundStyle(L4NETheme.textPrimary)
                }
                .font(.system(size: 20, weight: .black, design: .rounded))
                .tracking(1.6)

                Text(subtitle)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(L4NETheme.textSecondary)
                    .tracking(2.0)
            }
        }
    }
}

/// Reusable high-contrast metric badge card in the L4NE dark athletic style.
public struct L4NEMetricTile: View {
    public let title: String
    public let value: String
    public let subtitle: String?
    public let accentColor: Color

    public init(
        title: String,
        value: String,
        subtitle: String? = nil,
        accentColor: Color = L4NETheme.electricLime
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(L4NETheme.textSecondary)
                .tracking(1.1)

            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(accentColor)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(L4NETheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(L4NETheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(L4NETheme.border, lineWidth: 1)
        )
    }
}
