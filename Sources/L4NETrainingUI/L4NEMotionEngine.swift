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

// MARK: - 1. Visual Intensity Mode (Minimalist Round Graphite vs. Maximized Cinematic Duolingo-Grade Animation)

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

// MARK: - 2. Procedural Audio Synthesizer & Tactile Haptics Engine (Zero External Asset Dependencies)

public enum L4NESoundCue: Sendable {
    case dropletTap       // Water droplet ping on numpad / button tap
    case blockDive        // Starting block plunge + rebound
    case waveSweep        // Mode / tab / theme transition chord
    case victoryFanfare   // Duolingo-style 4-note ascending celebration chime
    case deleteThud       // Soft low-frequency delete confirmation
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
            player.volume = 0.45
            player.prepareToPlay()
            player.play()
            activePlayers.removeAll { !$0.isPlaying }
            activePlayers.append(player)
        } catch {
            // Audio playback is best-effort on headless test runners
        }
        #endif
    }

    #if canImport(AVFoundation)
    private func prebuildWaveforms() {
        // 1. Water Droplet Ping: upward pitch bend 580Hz -> 1320Hz over 95ms
        cachedWavByCue["droplet"] = Self.makeWav(durationSec: 0.095) { t, dur in
            let progress = t / dur
            let freq = 580.0 + (780.0 * pow(progress, 1.35))
            let env = sin(progress * .pi) * exp(-progress * 2.4)
            return sin(2.0 * .pi * freq * t) * env * 0.65
        }

        // 2. Starting Block Dive & Rebound: deep sub plunge 220Hz->110Hz + splash harmonic 880Hz
        cachedWavByCue["dive"] = Self.makeWav(durationSec: 0.24) { t, dur in
            let progress = t / dur
            let freq = progress < 0.45
                ? (240.0 - 130.0 * (progress / 0.45))
                : (320.0 + 560.0 * ((progress - 0.45) / 0.55))
            let env = exp(-progress * 3.0)
            let sub = sin(2.0 * .pi * freq * t)
            let harmonic = 0.35 * sin(2.0 * .pi * (freq * 2.0) * t)
            return (sub + harmonic) * env * 0.6
        }

        // 3. Rising Wave Chord: smooth lush triad swell (A4 + C#5 + E5)
        cachedWavByCue["wave"] = Self.makeWav(durationSec: 0.22) { t, dur in
            let p = t / dur
            let env = sin(p * .pi) * exp(-p * 1.6)
            let s1 = sin(2.0 * .pi * 440.0 * t)
            let s2 = sin(2.0 * .pi * 554.37 * t)
            let s3 = sin(2.0 * .pi * 659.25 * t)
            return ((s1 + s2 + s3) / 3.0) * env * 0.55
        }

        // 4. Duolingo-Style Victory Arpeggio Fanfare: C5 -> E5 -> G5 -> C6
        cachedWavByCue["fanfare"] = Self.makeWav(durationSec: 0.42) { t, _ in
            let notes: [Double] = [523.25, 659.25, 783.99, 1046.50]
            let stepDur = 0.095
            let idx = min(notes.count - 1, max(0, Int(t / stepDur)))
            let localT = t - (Double(idx) * stepDur)
            let freq = notes[idx]
            let localEnv = exp(-localT * 9.0)
            let fundamental = sin(2.0 * .pi * freq * t)
            let overtone = 0.3 * sin(2.0 * .pi * freq * 2.0 * t)
            return (fundamental + overtone) * localEnv * 0.65
        }

        // 5. Delete Thud: 180Hz -> 75Hz percussive decay
        cachedWavByCue["delete"] = Self.makeWav(durationSec: 0.14) { t, dur in
            let p = t / dur
            let freq = 180.0 - 105.0 * p
            let env = exp(-p * 5.0)
            return sin(2.0 * .pi * freq * t) * env * 0.6
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
        header.append(uint32LE(16)) // PCM chunk size
        header.append(uint16LE(1))  // AudioFormat = 1 (PCM)
        header.append(uint16LE(1))  // NumChannels = 1
        header.append(uint32LE(UInt32(sampleRate)))
        header.append(uint32LE(UInt32(sampleRate * 2))) // ByteRate
        header.append(uint16LE(2))  // BlockAlign
        header.append(uint16LE(16)) // BitsPerSample
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

// MARK: - 3. Maximized Physics Canvas: Falling Water Droplets, Rising Pool Waves & Rising Pennant Flags

/// Renders continuous 60fps falling droplets with splash ripples, rising harmonic waves,
/// and rising backstroke/race pennant flags (`σημαιάκια που ανεβαίνουν`) when Maximized mode is active.
public struct L4NECinematicAmbientBackground: View {
    public let palette: L4NEPalette
    public let isMaximized: Bool

    public init(palette: L4NEPalette, isMaximized: Bool) {
        self.palette = palette
        self.isMaximized = isMaximized
    }

    public var body: some View {
        ZStack {
            palette.bgCanvas.ignoresSafeArea()

            if isMaximized {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        let w = size.width
                        let h = size.height

                        // A. 3 Layered Rising Pool Waves at the bottom & mid-screen
                        for layer in 0..<3 {
                            let layerF = Double(layer)
                            let speed = 1.6 + layerF * 0.55
                            let amp: CGFloat = 12.0 + CGFloat(layer) * 5.0
                            let baseY = h - 110.0 + CGFloat(layer) * 28.0 - CGFloat(sin(t * 0.7 + layerF) * 10.0)

                            var wavePath = Path()
                            wavePath.move(to: CGPoint(x: 0, y: h))
                            wavePath.addLine(to: CGPoint(x: 0, y: baseY))

                            let step: CGFloat = 12.0
                            var x: CGFloat = 0
                            while x <= w + step {
                                let normX = Double(x / max(1, w))
                                let yOffset = sin(normX * .pi * (3.0 + layerF) + t * speed) * Double(amp)
                                    + cos(normX * .pi * 5.0 - t * (speed * 0.7)) * Double(amp * 0.35)
                                wavePath.addLine(to: CGPoint(x: x, y: baseY + CGFloat(yOffset)))
                                x += step
                            }
                            wavePath.addLine(to: CGPoint(x: w, y: h))
                            wavePath.closeSubpath()

                            let waveColor = layer == 0
                                ? palette.secondaryAccent.opacity(0.11)
                                : (layer == 1 ? palette.primaryAccent.opacity(0.09) : palette.secondaryAccent.opacity(0.15))
                            context.fill(wavePath, with: .color(waveColor))

                            // Floating Lane-4 Rope Buoys bobbing on the top wave
                            if layer == 0 {
                                for buoyIdx in 0..<8 {
                                    let bx = CGFloat(buoyIdx) * (w / 7.0)
                                    let normX = Double(bx / max(1, w))
                                    let by = baseY + CGFloat(sin(normX * .pi * 3.0 + t * speed) * Double(amp))
                                    let isLane4Yellow = buoyIdx % 2 == 0
                                    let buoyRect = CGRect(x: bx - 7, y: by - 4, width: 14, height: 8)
                                    context.fill(
                                        Path(roundedRect: buoyRect, cornerRadius: 4),
                                        with: .color((isLane4Yellow ? palette.primaryAccent : palette.secondaryAccent).opacity(0.35))
                                    )
                                }
                            }
                        }

                        // B. Falling Water Droplets (`σταγόνες που πέφτουν`) + Splash Ripples
                        let dropletCount = 14
                        for i in 0..<dropletCount {
                            let seed = Double(i) * 1.731
                            let cycleDuration = 2.4 + Double(i % 4) * 0.45
                            let localPhase = (t + seed).truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
                            let xPos = CGFloat((sin(seed * 13.7) * 0.44 + 0.5)) * w
                            let yPos = CGFloat(localPhase * localPhase) * (h * 0.88)

                            if localPhase < 0.90 {
                                // Falling teardrop streak
                                let dropLen: CGFloat = 11.0 + CGFloat(localPhase) * 9.0
                                var dropPath = Path()
                                dropPath.move(to: CGPoint(x: xPos, y: yPos - dropLen))
                                dropPath.addQuadCurve(
                                    to: CGPoint(x: xPos, y: yPos),
                                    control: CGPoint(x: xPos + 3.5, y: yPos - 2)
                                )
                                dropPath.addQuadCurve(
                                    to: CGPoint(x: xPos, y: yPos - dropLen),
                                    control: CGPoint(x: xPos - 3.5, y: yPos - 2)
                                )
                                context.fill(
                                    dropPath,
                                    with: .color(palette.secondaryAccent.opacity(0.28))
                                )
                            } else {
                                // Splash ripple ring when droplet hits water surface
                                let splashProgress = (localPhase - 0.90) / 0.10
                                let radius = CGFloat(4.0 + splashProgress * 22.0)
                                let splashRect = CGRect(
                                    x: xPos - radius,
                                    y: yPos - radius * 0.35,
                                    width: radius * 2,
                                    height: radius * 0.7
                                )
                                context.stroke(
                                    Path(ellipseIn: splashRect),
                                    with: .color(palette.primaryAccent.opacity((1.0 - splashProgress) * 0.45)),
                                    lineWidth: 1.5
                                )
                            }
                        }

                        // C. Rising Race Pennant Flags (`σημαιάκια που ανεβαίνουν`) & Oxygen Bubbles
                        let flagCount = 9
                        for j in 0..<flagCount {
                            let fSeed = Double(j) * 2.39
                            let fCycle = 4.2 + Double(j % 3) * 0.8
                            let risePhase = (t + fSeed).truncatingRemainder(dividingBy: fCycle) / fCycle
                            let sway = sin(t * 2.8 + fSeed) * 14.0
                            let fx = CGFloat(0.08 + (Double(j) / Double(flagCount)) * 0.84) * w + CGFloat(sway)
                            let fy = h * CGFloat(1.0 - risePhase)
                            let alpha = sin(risePhase * .pi) * 0.32

                            // Triangular Swim Pennant Flag
                            var flag = Path()
                            flag.move(to: CGPoint(x: fx, y: fy - 10))
                            flag.addLine(to: CGPoint(x: fx + 15, y: fy - 4))
                            flag.addLine(to: CGPoint(x: fx, y: fy + 2))
                            flag.closeSubpath()

                            let flagColor = (j % 2 == 0) ? palette.primaryAccent : palette.prGold
                            context.fill(flag, with: .color(flagColor.opacity(alpha)))

                            // Pole line
                            var pole = Path()
                            pole.move(to: CGPoint(x: fx, y: fy - 11))
                            pole.addLine(to: CGPoint(x: fx, y: fy + 7))
                            context.stroke(pole, with: .color(palette.textPrimary.opacity(alpha)), lineWidth: 1.3)

                            // Rising Bubble next to pennant
                            let bubbleR: CGFloat = 3.5 + CGFloat(j % 3) * 1.5
                            let bubbleRect = CGRect(x: fx - 12, y: fy + 8, width: bubbleR * 2, height: bubbleR * 2)
                            context.stroke(
                                Path(ellipseIn: bubbleRect),
                                with: .color(palette.secondaryAccent.opacity(alpha * 0.9)),
                                lineWidth: 1.1
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - 4. Animated Starting Block #4 (`Βατήρας που βυθίζεται και ξεκολλάει`)

/// Interactive & continuously animated Starting Block #4 that compresses into a rising wave
/// (`βυθίζεται`) and springs upward (`ξεκολλάει`) with splash droplets in Maximized mode.
public struct L4NEAnimatedStartingBlockBadge: View {
    public let palette: L4NEPalette
    public let isMaximized: Bool
    @State private var manualPlunge: Bool = false

    public init(palette: L4NEPalette, isMaximized: Bool) {
        self.palette = palette
        self.isMaximized = isMaximized
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: isMaximized ? (1.0 / 60.0) : 1.0)) { timeline in
            let t = isMaximized ? timeline.date.timeIntervalSinceReferenceDate : 0.0
            // Periodic dive-and-launch cycle: dips down then launches up with spring energy
            let waveCycle = sin(t * 2.6)
            let verticalOffset: CGFloat = manualPlunge
                ? 7.0
                : (isMaximized ? CGFloat(waveCycle * 4.2) : 0.0)
            let tiltDegrees: Double = manualPlunge
                ? 8.0
                : (isMaximized ? sin(t * 2.6 - 0.6) * 4.5 : 0.0)
            let scaleY: CGFloat = manualPlunge
                ? 0.88
                : (isMaximized ? (1.0 - CGFloat(max(0, waveCycle)) * 0.06) : 1.0)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.surface1)
                    .frame(width: 48, height: 48)
                    .overlay(
                        // Mini rising water wave inside the block badge
                        Canvas { ctx, sz in
                            guard isMaximized else { return }
                            let waterLevel = sz.height * 0.72 + CGFloat(sin(t * 3.1) * 3.0)
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: sz.height))
                            p.addLine(to: CGPoint(x: 0, y: waterLevel))
                            for x in stride(from: CGFloat(0), through: sz.width, by: 4) {
                                let y = waterLevel + CGFloat(sin(Double(x / sz.width) * .pi * 2.0 + t * 4.0) * 2.5)
                                p.addLine(to: CGPoint(x: x, y: y))
                            }
                            p.addLine(to: CGPoint(x: sz.width, y: sz.height))
                            p.closeSubpath()
                            ctx.fill(p, with: .color(palette.secondaryAccent.opacity(0.24)))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [palette.primaryAccent, palette.secondaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isMaximized ? 1.8 : 1.2
                            )
                    )
                    .shadow(
                        color: isMaximized ? palette.primaryAccent.opacity(0.35) : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 2
                    )

                L4NEStartingBlockIcon(
                    blockColor: palette.textPrimary,
                    cutoutColor: palette.primaryAccent,
                    size: 35
                )
                .scaleEffect(x: 1.0, y: scaleY, anchor: .bottom)
                .rotationEffect(.degrees(tiltDegrees))
                .offset(y: verticalOffset)
            }
            .onTapGesture {
                L4NESoundHapticsEngine.shared.trigger(.blockDive)
                withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                    manualPlunge = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.interpolatingSpring(stiffness: 320, damping: 12)) {
                        manualPlunge = false
                    }
                }
            }
        }
    }
}

// MARK: - 5. Per-Box Animated Wave/Shimmer Card Modifier & Animated Left-Right Icons

/// Gives every individual box/card its own smooth wave fill, specular shimmer, and interactive bounce in Maximized mode.
public struct L4NEInteractiveBoxModifier: ViewModifier {
    public let palette: L4NEPalette
    public let isMaximized: Bool
    public let phaseSeed: Double
    public let cornerRadius: CGFloat
    @State private var isPressed: Bool = false

    public func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: isMaximized ? (1.0 / 45.0) : 2.0)) { timeline in
            let t = isMaximized ? timeline.date.timeIntervalSinceReferenceDate : 0.0
            let floatY: CGFloat = isMaximized ? CGFloat(sin(t * 1.9 + phaseSeed) * 2.2) : 0.0
            let shimmerPhase = isMaximized ? (sin(t * 1.5 + phaseSeed) * 0.5 + 0.5) : 0.0

            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(palette.surface1)

                        if isMaximized {
                            // Subtle internal rising wave inside every card
                            Canvas { ctx, sz in
                                let waveY: CGFloat = sz.height * 0.82 + CGFloat(sin(t * 2.2 + phaseSeed) * 4.0)
                                var path = Path()
                                path.move(to: CGPoint(x: 0, y: sz.height))
                                path.addLine(to: CGPoint(x: 0, y: waveY))
                                let widthD: Double = max(1.0, Double(sz.width))
                                var x: CGFloat = 0
                                while x <= sz.width + 10 {
                                    let normX: Double = Double(x) / widthD
                                    let angle: Double = normX * Double.pi * 2.5 + t * 2.8 + phaseSeed
                                    let dy: CGFloat = CGFloat(sin(angle) * 4.5)
                                    let y: CGFloat = waveY + dy
                                    path.addLine(to: CGPoint(x: x, y: y))
                                    x += 10
                                }
                                path.addLine(to: CGPoint(x: sz.width, y: sz.height))
                                path.closeSubpath()
                                ctx.fill(path, with: .color(palette.primaryAccent.opacity(0.055)))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: isMaximized
                                    ? [
                                        palette.primaryAccent.opacity(0.35 + shimmerPhase * 0.35),
                                        palette.highlightEdge,
                                        palette.secondaryAccent.opacity(0.25 + (1.0 - shimmerPhase) * 0.30)
                                    ]
                                    : [palette.highlightEdge, palette.border, palette.border.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isMaximized ? 1.4 : 1.0
                        )
                )
                .shadow(
                    color: isMaximized
                        ? palette.primaryAccent.opacity(0.10 + shimmerPhase * 0.08)
                        : Color.black.opacity(palette.isLightMode ? 0.06 : 0.30),
                    radius: isMaximized ? 9 : 6,
                    x: 0,
                    y: isMaximized ? 4 : 3
                )
                .offset(y: floatY)
                .scaleEffect(isPressed ? 0.975 : 1.0)
        }
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

/// Animated Section Header with left & right oscillating icons (droplets, flags, waves, trophies) in Maximized mode.
public struct L4NEAnimatedSectionHeader: View {
    public let title: String
    public let leftIcon: String
    public let rightIcon: String
    public let palette: L4NEPalette
    public let isMaximized: Bool

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
        TimelineView(.animation(minimumInterval: isMaximized ? (1.0 / 45.0) : 2.0)) { timeline in
            let t = isMaximized ? timeline.date.timeIntervalSinceReferenceDate : 0.0
            let leftBounce = isMaximized ? CGFloat(sin(t * 3.4) * 3.0) : 0.0
            let rightBounce = isMaximized ? CGFloat(cos(t * 3.4) * 3.0) : 0.0
            let rot = isMaximized ? sin(t * 2.8) * 10.0 : 0.0

            HStack(spacing: 8) {
                if isMaximized {
                    Image(systemName: leftIcon)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(palette.secondaryAccent)
                        .offset(y: leftBounce)
                        .rotationEffect(.degrees(rot))
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
                        .offset(y: rightBounce)
                        .rotationEffect(.degrees(-rot))
                }
            }
        }
    }
}

// MARK: - 6. Duolingo-Style 3D Tactile Bouncy Button Style with Procedural Audio & Haptics

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
        self.lipColor = lipColor ?? surfaceColor.opacity(0.62)
        self.cornerRadius = cornerRadius
        self.isMaximized = isMaximized
        self.soundCue = soundCue
    }

    public func makeBody(configuration: Configuration) -> some View {
        let lipHeight: CGFloat = isMaximized ? 4.0 : 1.5
        let pressOffset: CGFloat = configuration.isPressed ? lipHeight : 0.0

        configuration.label
            .background(
                ZStack {
                    // Bottom 3D tactile lip (Duolingo push-button depth)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(lipColor)
                        .offset(y: lipHeight)

                    // Top active button face
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
                                    lineWidth: 1.1
                                )
                        )
                        .offset(y: pressOffset)
                }
            )
            .offset(y: pressOffset)
            .scaleEffect(configuration.isPressed ? (isMaximized ? 0.94 : 0.97) : 1.0)
            .animation(.interpolatingSpring(stiffness: 420, damping: 17), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    L4NESoundHapticsEngine.shared.trigger(soundCue)
                }
            }
    }
}
