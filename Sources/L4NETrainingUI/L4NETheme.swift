import SwiftUI
#if canImport(L4NETrainingCore)
import L4NETrainingCore
#endif

// MARK: - Hex Color Initializer

public extension Color {
    init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 15) * 17, (int & 15) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 255, int & 255)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 255, int >> 8 & 255, int & 255)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - Multi-Theme Palette (Minimalist Graphite · Bevel · Strava)

public struct L4NEPalette: Sendable {
    public let preset: ThemePreset
    public let isLightMode: Bool

    // Surfaces
    public let bgCanvas: Color
    public let surface1: Color
    public let surface2: Color
    public let surface3: Color
    public let recessedDisc: Color
    public let ringStefani: Color
    public let ringTrack: Color

    // Bevel Edges & Borders
    public let border: Color
    public let borderStrong: Color
    public let highlightEdge: Color

    // Typography
    public let textPrimary: Color
    public let textSecondary: Color
    public let textOnAccent: Color

    // Accents & Signals
    public let primaryAccent: Color
    public let secondaryAccent: Color
    public let prGold: Color
    public let signalGreen: Color
    public let warningAmber: Color
    public let regressionRed: Color

    public static func forPreset(_ preset: ThemePreset) -> L4NEPalette {
        switch preset {
        case .graphiteBevel:
            // Default Minimalist Titanium Graphite + Bevel Specular Edges + L4NE Electric Lime
            return L4NEPalette(
                preset: .graphiteBevel,
                isLightMode: false,
                bgCanvas: Color(hex: "101216"),
                surface1: Color(hex: "171A21"),
                surface2: Color(hex: "1F242D"),
                surface3: Color(hex: "282E3A"),
                recessedDisc: Color(hex: "0C0E12"),
                ringStefani: Color(hex: "232834"),
                ringTrack: Color(hex: "262C38"),
                border: Color.white.opacity(0.09),
                borderStrong: Color.white.opacity(0.18),
                highlightEdge: Color.white.opacity(0.16),
                textPrimary: Color(hex: "F8FAFC"),
                textSecondary: Color(hex: "94A3B8"),
                textOnAccent: Color(hex: "090B0E"),
                primaryAccent: Color(hex: "CCFF00"),
                secondaryAccent: Color(hex: "38BDF8"),
                prGold: Color(hex: "FACC15"),
                signalGreen: Color(hex: "34D399"),
                warningAmber: Color(hex: "F59E0B"),
                regressionRed: Color(hex: "F87171")
            )
        case .stravaObsidian:
            // Strava-inspired Obsidian Graphite + Signal Orange (#FC4C02) + Gold PR Badges
            return L4NEPalette(
                preset: .stravaObsidian,
                isLightMode: false,
                bgCanvas: Color(hex: "0D0F12"),
                surface1: Color(hex: "15181E"),
                surface2: Color(hex: "1D212A"),
                surface3: Color(hex: "262B36"),
                recessedDisc: Color(hex: "0A0B0E"),
                ringStefani: Color(hex: "222731"),
                ringTrack: Color(hex: "282D38"),
                border: Color.white.opacity(0.09),
                borderStrong: Color.white.opacity(0.18),
                highlightEdge: Color.white.opacity(0.15),
                textPrimary: Color(hex: "F8FAFC"),
                textSecondary: Color(hex: "9CA3AF"),
                textOnAccent: Color.white,
                primaryAccent: Color(hex: "FC4C02"),
                secondaryAccent: Color(hex: "F97316"),
                prGold: Color(hex: "FACC15"),
                signalGreen: Color(hex: "10B981"),
                warningAmber: Color(hex: "F59E0B"),
                regressionRed: Color(hex: "EF4444")
            )
        case .bevelNavy:
            // LoggedInWatch Graphite Navy Palette (#0F172A / #16213A / #38BDF8 / #EAB308)
            return L4NEPalette(
                preset: .bevelNavy,
                isLightMode: false,
                bgCanvas: Color(hex: "0F172A"),
                surface1: Color(hex: "16213A"),
                surface2: Color(hex: "1C2A48"),
                surface3: Color(hex: "24355A"),
                recessedDisc: Color(hex: "1A2644"),
                ringStefani: Color(hex: "121B30"),
                ringTrack: Color(hex: "2B3A5C"),
                border: Color.white.opacity(0.10),
                borderStrong: Color.white.opacity(0.18),
                highlightEdge: Color.white.opacity(0.16),
                textPrimary: Color(hex: "F1F5F9"),
                textSecondary: Color(hex: "A9B8CE"),
                textOnAccent: Color(hex: "0F172A"),
                primaryAccent: Color(hex: "38BDF8"),
                secondaryAccent: Color(hex: "EAB308"),
                prGold: Color(hex: "EAB308"),
                signalGreen: Color(hex: "7FC791"),
                warningAmber: Color(hex: "EA9F41"),
                regressionRed: Color(hex: "FA8A8A")
            )
        case .lane4Carbon:
            // Pure OLED Carbon Black + High-Voltage Lime
            return L4NEPalette(
                preset: .lane4Carbon,
                isLightMode: false,
                bgCanvas: Color(hex: "060709"),
                surface1: Color(hex: "0F1217"),
                surface2: Color(hex: "171C24"),
                surface3: Color(hex: "202631"),
                recessedDisc: Color(hex: "050608"),
                ringStefani: Color(hex: "191E26"),
                ringTrack: Color(hex: "202733"),
                border: Color.white.opacity(0.10),
                borderStrong: Color.white.opacity(0.20),
                highlightEdge: Color.white.opacity(0.18),
                textPrimary: Color(hex: "FFFFFF"),
                textSecondary: Color(hex: "94A3B8"),
                textOnAccent: Color.black,
                primaryAccent: Color(hex: "D4FF00"),
                secondaryAccent: Color(hex: "00F0FF"),
                prGold: Color(hex: "FDE047"),
                signalGreen: Color(hex: "22C55E"),
                warningAmber: Color(hex: "F59E0B"),
                regressionRed: Color(hex: "EF4444")
            )
        case .minimalAlabaster:
            // Minimalist Daylight Lab (Bevel Light Alabaster + Deep Graphite Typography)
            return L4NEPalette(
                preset: .minimalAlabaster,
                isLightMode: true,
                bgCanvas: Color(hex: "F3F4F6"),
                surface1: Color(hex: "FFFFFF"),
                surface2: Color(hex: "E5E7EB"),
                surface3: Color(hex: "D1D5DB"),
                recessedDisc: Color(hex: "EEF0F4"),
                ringStefani: Color(hex: "D1D5DB"),
                ringTrack: Color(hex: "E2E8F0"),
                border: Color.black.opacity(0.08),
                borderStrong: Color.black.opacity(0.15),
                highlightEdge: Color.white.opacity(0.90),
                textPrimary: Color(hex: "111827"),
                textSecondary: Color(hex: "4B5563"),
                textOnAccent: Color.white,
                primaryAccent: Color(hex: "111827"),
                secondaryAccent: Color(hex: "FC4C02"),
                prGold: Color(hex: "D97706"),
                signalGreen: Color(hex: "059669"),
                warningAmber: Color(hex: "D97706"),
                regressionRed: Color(hex: "DC2626")
            )
        }
    }

    public var volumeStrainGradient: LinearGradient {
        LinearGradient(
            colors: [primaryAccent, secondaryAccent],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    public var consistencyGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "4DA689"), signalGreen],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    public var recoverySleepGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "6366F1"), Color(hex: "38BDF8")],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
}

/// Static fallback theme accessor so existing views can gradually or directly read dynamic palette tokens.
public enum L4NETheme {
    public static var activePalette: L4NEPalette = .forPreset(.graphiteBevel)

    public static var background: Color { activePalette.bgCanvas }
    public static var cardSurface: Color { activePalette.surface1 }
    public static var mutedSurface: Color { activePalette.surface2 }
    public static var raisedSurface: Color { activePalette.surface3 }
    public static var border: Color { activePalette.border }
    public static var highlightEdge: Color { activePalette.highlightEdge }
    public static var electricLime: Color { activePalette.primaryAccent }
    public static var prGold: Color { activePalette.prGold }
    public static var signalGreen: Color { activePalette.signalGreen }
    public static var warningAmber: Color { activePalette.warningAmber }
    public static var regressionRed: Color { activePalette.regressionRed }
    public static var textPrimary: Color { activePalette.textPrimary }
    public static var textSecondary: Color { activePalette.textSecondary }
    public static var textOnAccent: Color { activePalette.textOnAccent }
}

// MARK: - Bevel Tactile Card Modifier & Button Style (Ported from LoggedInWatch Bevel Design)

public struct L4NEBevelCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 16
    public var palette: L4NEPalette = L4NETheme.activePalette
    public var useSecondarySurface: Bool = false
    public var hasInnerGlow: Bool = false

    public func body(content: Content) -> some View {
        let fillSurface = useSecondarySurface ? palette.surface2 : palette.surface1
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        palette.highlightEdge,
                                        palette.border,
                                        palette.border.opacity(0.10)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        Group {
                            if hasInnerGlow {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke(palette.primaryAccent.opacity(0.28), lineWidth: 1.2)
                            }
                        }
                    )
                    .shadow(
                        color: Color.black.opacity(palette.isLightMode ? 0.06 : 0.32),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            )
    }
}

public extension View {
    func l4neBevelCard(
        cornerRadius: CGFloat = 16,
        palette: L4NEPalette = L4NETheme.activePalette,
        useSecondarySurface: Bool = false,
        hasInnerGlow: Bool = false
    ) -> some View {
        self.modifier(
            L4NEBevelCardModifier(
                cornerRadius: cornerRadius,
                palette: palette,
                useSecondarySurface: useSecondarySurface,
                hasInnerGlow: hasInnerGlow
            )
        )
    }
}

public struct L4NETactileBevelButtonStyle: ButtonStyle {
    public var surfaceColor: Color
    public var cornerRadius: CGFloat

    public init(surfaceColor: Color = L4NETheme.cardSurface, cornerRadius: CGFloat = 12) {
        self.surfaceColor = surfaceColor
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? surfaceColor.opacity(0.82) : surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [L4NETheme.highlightEdge, L4NETheme.border],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.interpolatingSpring(stiffness: 380, damping: 24), value: configuration.isPressed)
    }
}

// MARK: - Bevel Concentric Rings Cockpit Card (Volume/Strain · Consistency · Recovery/Sleep)

/// Triple concentric Bevel rings inspired by Bevel & LoggedInWatch (`BevelRingsView.swift`).
/// Enforces "Unknown != 0": when a ring metric is `nil`, renders an empty recessed track.
public struct L4NEBevelRingsCard: View {
    public let palette: L4NEPalette
    public let volumePct: Double?       // 0..=100%
    public let consistencyPct: Double?  // 0..=100% (e.g. 100 - CV%)
    public let recoveryPct: Double?     // 0..=100% (from HealthKit HRV/Sleep baseline)
    public let totalMetersText: String
    public let bestImprovementText: String
    public let recoveryContextText: String

    public init(
        palette: L4NEPalette = L4NETheme.activePalette,
        volumePct: Double?,
        consistencyPct: Double?,
        recoveryPct: Double?,
        totalMetersText: String,
        bestImprovementText: String,
        recoveryContextText: String
    ) {
        self.palette = palette
        self.volumePct = volumePct
        self.consistencyPct = consistencyPct
        self.recoveryPct = recoveryPct
        self.totalMetersText = totalMetersText
        self.bestImprovementText = bestImprovementText
        self.recoveryContextText = recoveryContextText
    }

    public var body: some View {
        HStack(spacing: 18) {
            // Triple Concentric Bevel Ring Geometry
            ZStack {
                Circle()
                    .fill(palette.recessedDisc)
                    .frame(width: 74, height: 74)
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 2)

                Circle()
                    .stroke(palette.ringStefani, lineWidth: 2)
                    .frame(width: 112, height: 112)

                // Outer Ring: Training Volume / Load
                L4NESingleBevelRing(
                    diameter: 112,
                    lineWidth: 8,
                    normalizedValue: volumePct.map { $0 / 100.0 },
                    trackColor: palette.ringTrack,
                    gradient: palette.volumeStrainGradient
                )

                // Middle Ring: Deterministic Consistency (100% - CV%)
                L4NESingleBevelRing(
                    diameter: 92,
                    lineWidth: 7,
                    normalizedValue: consistencyPct.map { $0 / 100.0 },
                    trackColor: palette.ringTrack,
                    gradient: palette.consistencyGradient
                )

                // Inner Ring: Recovery & Sleep Context
                L4NESingleBevelRing(
                    diameter: 74,
                    lineWidth: 6,
                    normalizedValue: recoveryPct.map { $0 / 100.0 },
                    trackColor: palette.ringTrack,
                    gradient: palette.recoverySleepGradient
                )

                VStack(spacing: 0) {
                    Text(consistencyPct.map { String(format: "%.0f%%", $0) } ?? "—")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(palette.textPrimary)
                    Text("FORM")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .frame(width: 114, height: 114)

            // Bevel Ring Legend & Strava Summary Metrics
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(palette.primaryAccent).frame(width: 7, height: 7)
                    Text("VOLUME LOAD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                    Text(totalMetersText)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(palette.textPrimary)
                }

                HStack(spacing: 6) {
                    Circle().fill(palette.signalGreen).frame(width: 7, height: 7)
                    Text("CONSISTENCY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                    Text(consistencyPct.map { String(format: "%.1f%%", $0) } ?? "—")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(palette.signalGreen)
                }

                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "38BDF8")).frame(width: 7, height: 7)
                    Text("RECOVERY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                    Text(recoveryContextText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(palette.textPrimary)
                }

                Divider().overlay(palette.border)

                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.prGold)
                    Text(bestImprovementText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.prGold)
                }
            }
        }
        .padding(16)
        .l4neBevelCard(cornerRadius: 18, palette: palette)
    }
}

struct L4NESingleBevelRing: View {
    let diameter: CGFloat
    let lineWidth: CGFloat
    let normalizedValue: Double?
    let trackColor: Color
    let gradient: LinearGradient

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: diameter - lineWidth, height: diameter - lineWidth)

            if let val = normalizedValue {
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(max(val, 0.0), 1.0)))
                    .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: diameter - lineWidth, height: diameter - lineWidth)
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

// MARK: - Strava-Inspired Horizontal Split Pace Bar Visualization

/// Strava-style horizontal lap/rep pace bars showing relative speed per repetition,
/// highlighting the fastest repetition with a PR Gold / Accent badge.
public struct L4NEStravaSplitsBarView: View {
    public let reps: [RepRecord]
    public let palette: L4NEPalette

    public init(reps: [RepRecord], palette: L4NEPalette = L4NETheme.activePalette) {
        self.reps = reps
        self.palette = palette
    }

    public var body: some View {
        let validReps = reps.filter { !$0.isSkipped && ($0.durationMs ?? 0) > 0 }
        let metricValues = validReps.map { Double($0.paceMsPer100m ?? $0.durationMs ?? 1) }
        let minVal = metricValues.min() ?? 1.0
        let maxVal = max(minVal + 1.0, metricValues.max() ?? 1.0)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("STRAVA SPLIT PACE DISTRIBUTION")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .tracking(1.1)
                Spacer()
                Text("FASTEST REP HIGHLIGHTED")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.prGold)
            }

            ForEach(validReps.prefix(12)) { rep in
                let val = Double(rep.paceMsPer100m ?? rep.durationMs ?? 1)
                let isFastest = abs(val - minVal) < 1.0
                // Faster time (closer to minVal) gets a fuller velocity bar (0.55..1.0)
                let speedRatio = 1.0 - ((val - minVal) / (maxVal - minVal)) * 0.42

                HStack(spacing: 8) {
                    Text("#\(rep.slotIndex)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isFastest ? palette.prGold : palette.textSecondary)
                        .frame(width: 24, alignment: .leading)

                    if let dist = rep.distanceM {
                        Text("\(dist)m")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(palette.textSecondary)
                            .frame(width: 34, alignment: .leading)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(palette.surface2)
                                .frame(height: 8)

                            Capsule()
                                .fill(
                                    isFastest
                                        ? LinearGradient(colors: [palette.prGold, palette.primaryAccent], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [palette.primaryAccent.opacity(0.65), palette.primaryAccent], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(18, geo.size.width * CGFloat(speedRatio)), height: 8)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 14)

                    if isFastest {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(palette.prGold)
                    }

                    if let dur = rep.durationMs {
                        Text(L4NEDurationFormatter.formatMs(dur))
                            .font(.system(size: 11, weight: isFastest ? .black : .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(isFastest ? palette.prGold : palette.textPrimary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Brand Wordmark & Metric Tile

public struct L4NEBrandWordmark: View {
    public let subtitle: String
    public let palette: L4NEPalette

    public init(subtitle: String = "PERFORMANCE", palette: L4NEPalette = L4NETheme.activePalette) {
        self.subtitle = subtitle
        self.palette = palette
    }

    public var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.surface1)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(palette.primaryAccent.opacity(0.75), lineWidth: 1.5)
                    )

                HStack(spacing: 3) {
                    Rectangle()
                        .fill(palette.textSecondary.opacity(0.35))
                        .frame(width: 2, height: 20)
                    Rectangle()
                        .fill(palette.primaryAccent)
                        .frame(width: 4, height: 22)
                    Rectangle()
                        .fill(palette.textSecondary.opacity(0.35))
                        .frame(width: 2, height: 20)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 0) {
                    Text("L")
                        .foregroundStyle(palette.textPrimary)
                    Text("4")
                        .foregroundStyle(palette.primaryAccent)
                    Text("NE")
                        .foregroundStyle(palette.textPrimary)
                }
                .font(.system(size: 20, weight: .black, design: .rounded))
                .tracking(1.6)

                Text(subtitle)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .tracking(1.8)
            }
        }
    }
}

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
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(L4NETheme.textSecondary)
                .tracking(1.1)

            Text(value)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accentColor)
                .minimumScaleFactor(0.7)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(L4NETheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .l4neBevelCard(cornerRadius: 15)
    }
}
