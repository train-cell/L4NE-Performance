import SwiftUI
import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(L4NETrainingCore)
import L4NETrainingCore
#endif

// MARK: - 1. Visual Mode & Granular Custom Maximize Configuration

public enum L4NEVisualMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case minimal = "minimal"
    case maximized = "maximized"

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .minimal: return "Minimal"
        case .maximized: return "Maximized"
        }
    }

    public var badgeTitle: String {
        switch self {
        case .minimal: return "◐ MINIMAL"
        case .maximized: return "🎬 MAXIMIZED"
        }
    }
}

/// Granular, athlete-customizable Maximize Configuration so the user can choose
/// *how much* Maximize they want (0%..100% intensity + individual feature switches).
public struct L4NEMaximizeConfig: Codable, Equatable, Sendable {
    /// Master intensity percentage (`0.0 ... 100.0`). `0` = Minimal, `100` = Ultra Max.
    public var intensityPct: Double
    public var dropletsEnabled: Bool
    public var wavesEnabled: Bool
    public var flagsEnabled: Bool
    public var animatedStartingBlockEnabled: Bool
    public var animatedIconsAndCardsEnabled: Bool
    public var tactile3DButtonsEnabled: Bool
    public var soundAndHapticsEnabled: Bool

    public init(
        intensityPct: Double = 75.0,
        dropletsEnabled: Bool = true,
        wavesEnabled: Bool = true,
        flagsEnabled: Bool = true,
        animatedStartingBlockEnabled: Bool = true,
        animatedIconsAndCardsEnabled: Bool = true,
        tactile3DButtonsEnabled: Bool = true,
        soundAndHapticsEnabled: Bool = true
    ) {
        self.intensityPct = intensityPct
        self.dropletsEnabled = dropletsEnabled
        self.wavesEnabled = wavesEnabled
        self.flagsEnabled = flagsEnabled
        self.animatedStartingBlockEnabled = animatedStartingBlockEnabled
        self.animatedIconsAndCardsEnabled = animatedIconsAndCardsEnabled
        self.tactile3DButtonsEnabled = tactile3DButtonsEnabled
        self.soundAndHapticsEnabled = soundAndHapticsEnabled
    }

    public var isEffectivelyMaximized: Bool {
        intensityPct > 5.0 && (
            dropletsEnabled || wavesEnabled || flagsEnabled ||
            animatedStartingBlockEnabled || animatedIconsAndCardsEnabled || tactile3DButtonsEnabled
        )
    }

    public var normalizedIntensity: Double {
        min(1.0, max(0.0, intensityPct / 100.0))
    }

    public static let minimalPreset = L4NEMaximizeConfig(
        intensityPct: 0.0,
        dropletsEnabled: false,
        wavesEnabled: false,
        flagsEnabled: false,
        animatedStartingBlockEnabled: false,
        animatedIconsAndCardsEnabled: false,
        tactile3DButtonsEnabled: false,
        soundAndHapticsEnabled: true
    )

    public static let subtlePreset = L4NEMaximizeConfig(
        intensityPct: 40.0,
        dropletsEnabled: false,
        wavesEnabled: true,
        flagsEnabled: false,
        animatedStartingBlockEnabled: true,
        animatedIconsAndCardsEnabled: true,
        tactile3DButtonsEnabled: true,
        soundAndHapticsEnabled: true
    )

    public static let balancedPreset = L4NEMaximizeConfig(
        intensityPct: 75.0,
        dropletsEnabled: true,
        wavesEnabled: true,
        flagsEnabled: true,
        animatedStartingBlockEnabled: true,
        animatedIconsAndCardsEnabled: true,
        tactile3DButtonsEnabled: true,
        soundAndHapticsEnabled: true
    )

    public static let ultraMaxPreset = L4NEMaximizeConfig(
        intensityPct: 100.0,
        dropletsEnabled: true,
        wavesEnabled: true,
        flagsEnabled: true,
        animatedStartingBlockEnabled: true,
        animatedIconsAndCardsEnabled: true,
        tactile3DButtonsEnabled: true,
        soundAndHapticsEnabled: true
    )
}

// MARK: - 2. Procedural Audio Synthesizer & Tactile Haptics Engine

public enum L4NESoundCue: Sendable {
    case dropletTap
    case blockDive
    case waveSweep
    case victoryFanfare
    case deleteThud
}

@MainActor
public final class L4NESoundHapticsEngine: ObservableObject {
    public static let shared = L4NESoundHapticsEngine()

    @Published public var soundEnabled: Bool = true
    @Published public var hapticsEnabled: Bool = true

    #if canImport(AVFoundation)
    private var activePlayers: [AVAudioPlayer] = []
    private var cachedWavByCue: [String: Data] = [:]
    #endif

    private init() {
        #if canImport(AVFoundation)
        prebuildWaveforms()
        #endif
    }

    public func trigger(_ cue: L4NESoundCue) {
        if hapticsEnabled {
            triggerHaptic(for: cue)
        }
        if soundEnabled {
            playSynthesizedSound(for: cue)
        }
    }

    private func triggerHaptic(for cue: L4NESoundCue) {
        #if canImport(UIKit)
        switch cue {
        case .dropletTap:
            let gen = UIImpactFeedbackGenerator(style: .rigid)
            gen.impactOccurred(intensity: 0.75)
        case .blockDive:
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred(intensity: 1.0)
        case .waveSweep:
            let gen = UIImpactFeedbackGenerator(style: .soft)
            gen.impactOccurred(intensity: 0.85)
        case .victoryFanfare:
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        case .deleteThud:
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
        }
        #endif
    }

    private func playSynthesizedSound(for cue: L4NESoundCue) {
        #if canImport(AVFoundation)
        let key: String
        switch cue {
        case .dropletTap: key = "droplet"
        case .blockDive: key = "dive"
        case .waveSweep: key = "wave"
        case .victoryFanfare: key = "fanfare"
        case .deleteThud: key = "delete"
        }
        guard let wavData = cachedWavByCue[key] else { return }
        do {
            let player = try AVAudioPlayer(data: wavData)
            player.volume = 0.42
            player.prepareToPlay()
            player.play()
            activePlayers.removeAll { !$0.isPlaying }
            activePlayers.append(player)
        } catch {}
        #endif
    }

    #if canImport(AVFoundation)
    private func prebuildWaveforms() {
        cachedWavByCue["droplet"] = Self.makeWav(durationSec: 0.09) { t, dur in
            let progress = t / dur
            let freq = 580.0 + (780.0 * pow(progress, 1.35))
            let env = sin(progress * .pi) * exp(-progress * 2.4)
            return sin(2.0 * .pi * freq * t) * env * 0.65
        }
        cachedWavByCue["dive"] = Self.makeWav(durationSec: 0.22) { t, dur in
            let progress = t / dur
            let freq = progress < 0.45
                ? (240.0 - 130.0 * (progress / 0.45))
                : (320.0 + 560.0 * ((progress - 0.45) / 0.55))
            let env = exp(-progress * 3.0)
            return (sin(2.0 * .pi * freq * t) + 0.35 * sin(2.0 * .pi * (freq * 2.0) * t)) * env * 0.6
        }
        cachedWavByCue["wave"] = Self.makeWav(durationSec: 0.20) { t, dur in
            let p = t / dur
            let env = sin(p * .pi) * exp(-p * 1.6)
            return ((sin(2.0 * .pi * 440.0 * t) + sin(2.0 * .pi * 554.37 * t) + sin(2.0 * .pi * 659.25 * t)) / 3.0) * env * 0.55
        }
        cachedWavByCue["fanfare"] = Self.makeWav(durationSec: 0.38) { t, _ in
            let notes: [Double] = [523.25, 659.25, 783.99, 1046.50]
            let stepDur = 0.09
            let idx = min(notes.count - 1, max(0, Int(t / stepDur)))
            let localT = t - (Double(idx) * stepDur)
            let freq = notes[idx]
            let localEnv = exp(-localT * 9.0)
            return (sin(2.0 * .pi * freq * t) + 0.3 * sin(2.0 * .pi * freq * 2.0 * t)) * localEnv * 0.65
        }
        cachedWavByCue["delete"] = Self.makeWav(durationSec: 0.13) { t, dur in
            let p = t / dur
            let freq = 180.0 - 105.0 * p
            return sin(2.0 * .pi * freq * t) * exp(-p * 5.0) * 0.6
        }
    }

    private static func makeWav(durationSec: Double, sampleAt: (Double, Double) -> Double) -> Data {
        let sampleRate: Int = 22_050
        let totalSamples = max(1, Int(Double(sampleRate) * durationSec))
        var pcm = [Int16](repeating: 0, count: totalSamples)
        for i in 0..<totalSamples {
            let t = Double(i) / Double(sampleRate)
            let val = max(-1.0, min(1.0, sampleAt(t, durationSec)))
            pcm[i] = Int16(val * 32_000.0)
        }
        let dataSize = totalSamples * 2
        let fileSize = 36 + dataSize
        var header = Data()
        header.append(contentsOf: Array("RIFF".utf8))
        header.append(uint32LE(UInt32(fileSize)))
        header.append(contentsOf: Array("WAVEfmt ".utf8))
        header.append(uint32LE(16))
        header.append(uint16LE(1))
        header.append(uint16LE(1))
        header.append(uint32LE(UInt32(sampleRate)))
        header.append(uint32LE(UInt32(sampleRate * 2)))
        header.append(uint16LE(2))
        header.append(uint16LE(16))
        header.append(contentsOf: Array("data".utf8))
        header.append(uint32LE(UInt32(dataSize)))
        pcm.withUnsafeBytes { rawBuf in
            header.append(contentsOf: rawBuf)
        }
        return header
    }

    private static func uint32LE(_ v: UInt32) -> Data {
        var le = v.littleEndian
        return Data(bytes: &le, count: 4)
    }

    private static func uint16LE(_ v: UInt16) -> Data {
        var le = v.littleEndian
        return Data(bytes: &le, count: 2)
    }
    #endif
}

// MARK: - 3. GPU-Friendly Ambient Physics Background (Scales with Custom Maximize Config)

public struct L4NECinematicAmbientBackground: View {
    public let palette: L4NEPalette
    public let config: L4NEMaximizeConfig

    public init(palette: L4NEPalette, config: L4NEMaximizeConfig) {
        self.palette = palette
        self.config = config
    }

    public init(palette: L4NEPalette, isMaximized: Bool) {
        self.palette = palette
        self.config = isMaximized ? .balancedPreset : .minimalPreset
    }

    public var body: some View {
        ZStack {
            palette.bgCanvas.ignoresSafeArea()

            if config.isEffectivelyMaximized && (config.wavesEnabled || config.dropletsEnabled || config.flagsEnabled) {
                let norm = config.normalizedIntensity
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        let w = size.width
                        let h = size.height

                        // A. Rising Pool Waves (`κύματα που ανεβαίνουν`)
                        if config.wavesEnabled {
                            let waveLayers = norm >= 0.7 ? 3 : (norm >= 0.35 ? 2 : 1)
                            for layer in 0..<waveLayers {
                                let layerF = Double(layer)
                                let speed = 1.4 + layerF * 0.45
                                let amp: CGFloat = CGFloat(8.0 + Double(layer) * 4.0) * CGFloat(0.5 + norm * 0.6)
                                let baseY = h - 105.0 + CGFloat(layer) * 26.0 - CGFloat(sin(t * 0.6 + layerF) * 8.0)

                                var wavePath = Path()
                                wavePath.move(to: CGPoint(x: 0, y: h))
                                wavePath.addLine(to: CGPoint(x: 0, y: baseY))

                                let step: CGFloat = 18.0
                                var x: CGFloat = 0
                                while x <= w + step {
                                    let normX = Double(x / max(1, w))
                                    let yOffset = sin(normX * .pi * (2.8 + layerF) + t * speed) * Double(amp)
                                    wavePath.addLine(to: CGPoint(x: x, y: baseY + CGFloat(yOffset)))
                                    x += step
                                }
                                wavePath.addLine(to: CGPoint(x: w, y: h))
                                wavePath.closeSubpath()

                                let waveColor = layer == 0
                                    ? palette.secondaryAccent.opacity(0.11 * norm)
                                    : palette.primaryAccent.opacity(0.10 * norm)
                                context.fill(wavePath, with: .color(waveColor))

                                if layer == 0 {
                                    for buoyIdx in 0..<7 {
                                        let bx = CGFloat(buoyIdx) * (w / 6.0)
                                        let normX = Double(bx / max(1, w))
                                        let by = baseY + CGFloat(sin(normX * .pi * 2.8 + t * speed) * Double(amp))
                                        let isLane4 = buoyIdx % 2 == 0
                                        let buoyRect = CGRect(x: bx - 6, y: by - 3.5, width: 12, height: 7)
                                        context.fill(
                                            Path(roundedRect: buoyRect, cornerRadius: 3.5),
                                            with: .color((isLane4 ? palette.primaryAccent : palette.secondaryAccent).opacity(0.32 * norm))
                                        )
                                    }
                                }
                            }
                        }

                        // B. Falling Water Droplets (`σταγόνες που πέφτουν`) + Splash Ripples
                        if config.dropletsEnabled {
                            let dropletCount = max(2, Int((12.0 * norm).rounded()))
                            for i in 0..<dropletCount {
                                let seed = Double(i) * 1.731
                                let cycleDuration = 2.6 + Double(i % 4) * 0.45
                                let localPhase = (t + seed).truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
                                let xPos = CGFloat((sin(seed * 13.7) * 0.44 + 0.5)) * w
                                let yPos = CGFloat(localPhase * localPhase) * (h * 0.88)

                                if localPhase < 0.90 {
                                    let dropLen: CGFloat = 10.0 + CGFloat(localPhase) * 8.0
                                    var dropPath = Path()
                                    dropPath.move(to: CGPoint(x: xPos, y: yPos - dropLen))
                                    dropPath.addQuadCurve(
                                        to: CGPoint(x: xPos, y: yPos),
                                        control: CGPoint(x: xPos + 3.2, y: yPos - 2)
                                    )
                                    dropPath.addQuadCurve(
                                        to: CGPoint(x: xPos, y: yPos - dropLen),
                                        control: CGPoint(x: xPos - 3.2, y: yPos - 2)
                                    )
                                    context.fill(
                                        dropPath,
                                        with: .color(palette.secondaryAccent.opacity(0.26 * norm))
                                    )
                                } else {
                                    let splashProgress = (localPhase - 0.90) / 0.10
                                    let radius = CGFloat(4.0 + splashProgress * 20.0)
                                    let splashRect = CGRect(
                                        x: xPos - radius,
                                        y: yPos - radius * 0.35,
                                        width: radius * 2,
                                        height: radius * 0.7
                                    )
                                    context.stroke(
                                        Path(ellipseIn: splashRect),
                                        with: .color(palette.primaryAccent.opacity((1.0 - splashProgress) * 0.45 * norm)),
                                        lineWidth: 1.4
                                    )
                                }
                            }
                        }

                        // C. Rising Race Pennant Flags (`σημαιάκια που ανεβαίνουν`) & Oxygen Bubbles
                        if config.flagsEnabled {
                            let flagCount = max(2, Int((8.0 * norm).rounded()))
                            for j in 0..<flagCount {
                                let fSeed = Double(j) * 2.39
                                let fCycle = 4.5 + Double(j % 3) * 0.8
                                let risePhase = (t + fSeed).truncatingRemainder(dividingBy: fCycle) / fCycle
                                let sway = sin(t * 2.4 + fSeed) * 12.0
                                let fx = CGFloat(0.08 + (Double(j) / Double(max(1, flagCount))) * 0.84) * w + CGFloat(sway)
                                let fy = h * CGFloat(1.0 - risePhase)
                                let alpha = sin(risePhase * .pi) * 0.30 * norm

                                var flag = Path()
                                flag.move(to: CGPoint(x: fx, y: fy - 9))
                                flag.addLine(to: CGPoint(x: fx + 14, y: fy - 3.5))
                                flag.addLine(to: CGPoint(x: fx, y: fy + 2))
                                flag.closeSubpath()

                                let flagColor = (j % 2 == 0) ? palette.primaryAccent : palette.prGold
                                context.fill(flag, with: .color(flagColor.opacity(alpha)))

                                var pole = Path()
                                pole.move(to: CGPoint(x: fx, y: fy - 10))
                                pole.addLine(to: CGPoint(x: fx, y: fy + 7))
                                context.stroke(pole, with: .color(palette.textPrimary.opacity(alpha)), lineWidth: 1.2)

                                let bubbleR: CGFloat = 3.2 + CGFloat(j % 3) * 1.3
                                let bubbleRect = CGRect(x: fx - 11, y: fy + 7, width: bubbleR * 2, height: bubbleR * 2)
                                context.stroke(
                                    Path(ellipseIn: bubbleRect),
                                    with: .color(palette.secondaryAccent.opacity(alpha * 0.9)),
                                    lineWidth: 1.0
                                )
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - 4. Animated Starting Block #4 (`Βατήρας με το 4 που βυθίζεται και ξεκολλάει` — Zero CPU Lag)

public struct L4NEAnimatedStartingBlockBadge: View {
    public let palette: L4NEPalette
    public let isMaximized: Bool
    @State private var isBouncing: Bool = false
    @State private var manualPlunge: Bool = false

    private let l4neIconBlue = Color(hex: "1D4ED8")

    public init(palette: L4NEPalette, isMaximized: Bool) {
        self.palette = palette
        self.isMaximized = isMaximized
    }

    public var body: some View {
        ZStack {
            // Pure White outer icon square ("το εικονίδιο γύρω γύρω να είναι άσπρο")
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(l4neIconBlue.opacity(0.30), lineWidth: 1.4)
                )
                .shadow(
                    color: isMaximized ? palette.primaryAccent.opacity(0.28) : Color.black.opacity(0.18),
                    radius: 5,
                    x: 0,
                    y: 2
                )

            // Blue Starting Block with White '4' inside + "L4NE" underneath
            VStack(spacing: -2) {
                L4NEStartingBlockIcon(
                    blockColor: l4neIconBlue,
                    cutoutColor: Color.white,
                    size: 33
                )
                .scaleEffect(x: 1.0, y: manualPlunge ? 0.86 : (isMaximized && isBouncing ? 0.94 : 1.0), anchor: .bottom)
                .rotationEffect(.degrees(manualPlunge ? 7.0 : (isMaximized && isBouncing ? 3.2 : -1.5)))
                .offset(y: manualPlunge ? 4.0 : (isMaximized && isBouncing ? 1.8 : -1.0))

                Text("L4NE")
                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(l4neIconBlue)
                    .lineLimit(1)
            }
        }
        .onAppear {
            guard isMaximized else { return }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                isBouncing = true
            }
        }
        .onChange(of: isMaximized) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                    isBouncing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    isBouncing = false
                }
            }
        }
        .onTapGesture {
            L4NESoundHapticsEngine.shared.trigger(.blockDive)
            withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) {
                manualPlunge = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.interpolatingSpring(stiffness: 320, damping: 12)) {
                    manualPlunge = false
                }
            }
        }
    }
}

// MARK: - 5. Zero-Lag CoreAnimation Card Modifier & Animated Left-Right Section Headers

/// GPU-accelerated card modifier: uses RenderServer CoreAnimation transitions instead of per-card TimelineView timers
/// so scrolling through the Cockpit and Templates is 100% lag-free on both Simulator and device.
public struct L4NEInteractiveBoxModifier: ViewModifier {
    public let palette: L4NEPalette
    public let isMaximized: Bool
    public let phaseSeed: Double
    public let cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(palette.surface1)

                    if isMaximized {
                        LinearGradient(
                            colors: [
                                palette.primaryAccent.opacity(0.06),
                                Color.clear,
                                palette.secondaryAccent.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: isMaximized
                                ? [palette.primaryAccent.opacity(0.48), palette.highlightEdge, palette.secondaryAccent.opacity(0.35)]
                                : [palette.highlightEdge, palette.border, palette.border.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isMaximized ? 1.35 : 1.0
                    )
            )
            .shadow(
                color: isMaximized
                    ? palette.primaryAccent.opacity(0.12)
                    : Color.black.opacity(palette.isLightMode ? 0.06 : 0.28),
                radius: isMaximized ? 7 : 5,
                x: 0,
                y: 3
            )
    }
}

public extension View {
    func l4neAnimatedBox(
        palette: L4NEPalette = L4NETheme.activePalette,
        isMaximized: Bool,
        phaseSeed: Double = 0.0,
        cornerRadius: CGFloat = 16
    ) -> some View {
        self.modifier(
            L4NEInteractiveBoxModifier(
                palette: palette,
                isMaximized: isMaximized,
                phaseSeed: phaseSeed,
                cornerRadius: cornerRadius
            )
        )
    }
}

public struct L4NEAnimatedSectionHeader: View {
    public let title: String
    public let leftIcon: String
    public let rightIcon: String
    public let palette: L4NEPalette
    public let isMaximized: Bool
    @State private var pulse: Bool = false

    public init(
        title: String,
        leftIcon: String = "drop.fill",
        rightIcon: String = "flag.checkered.2.crossed",
        palette: L4NEPalette = L4NETheme.activePalette,
        isMaximized: Bool = true
    ) {
        self.title = title
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
        self.palette = palette
        self.isMaximized = isMaximized
    }

    public var body: some View {
        HStack(spacing: 8) {
            if isMaximized {
                Image(systemName: leftIcon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(palette.secondaryAccent)
                    .offset(y: pulse ? -2.0 : 2.0)
            }

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .tracking(1.1)

            Spacer()

            if isMaximized {
                Image(systemName: rightIcon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(palette.primaryAccent)
                    .offset(y: pulse ? 2.0 : -2.0)
            }
        }
        .onAppear {
            guard isMaximized else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - 6. Duolingo-Style 3D Tactile Bouncy Button Style

public struct L4NEDuolingo3DButtonStyle: ButtonStyle {
    public var surfaceColor: Color
    public var lipColor: Color
    public var cornerRadius: CGFloat
    public var isMaximized: Bool
    public var soundCue: L4NESoundCue

    public init(
        surfaceColor: Color = L4NETheme.cardSurface,
        lipColor: Color? = nil,
        cornerRadius: CGFloat = 12,
        isMaximized: Bool = true,
        soundCue: L4NESoundCue = .dropletTap
    ) {
        self.surfaceColor = surfaceColor
        self.lipColor = lipColor ?? surfaceColor.opacity(0.58)
        self.cornerRadius = cornerRadius
        self.isMaximized = isMaximized
        self.soundCue = soundCue
    }

    public func makeBody(configuration: Configuration) -> some View {
        let lipHeight: CGFloat = isMaximized ? 3.5 : 1.0
        let pressOffset: CGFloat = configuration.isPressed ? lipHeight : 0.0

        configuration.label
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(lipColor)
                        .offset(y: lipHeight)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(surfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [L4NETheme.highlightEdge, L4NETheme.border],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.0
                                )
                        )
                        .offset(y: pressOffset)
                }
            )
            .offset(y: pressOffset)
            .scaleEffect(configuration.isPressed ? (isMaximized ? 0.95 : 0.98) : 1.0)
            .animation(.interpolatingSpring(stiffness: 420, damping: 18), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    L4NESoundHapticsEngine.shared.trigger(soundCue)
                }
            }
    }
}
