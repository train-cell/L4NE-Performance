import SwiftUI
import Foundation
#if canImport(L4NETrainingCore)
import L4NETrainingCore
#endif

/// v1.1 Live Poolside Training Companion View
/// Provides a high-contrast monotonic stopwatch, wet-finger debounce protection (>= 0.80s),
/// automatic Fixed Rest & Send-Off cycle departure countdowns powered deterministically by `l4ne-core`,
/// and 1-tap session saving to SQLite.
public struct LivePoolsideTimerView: View {
    @ObservedObject var store: L4NEAppStore
    public let template: TemplateWithVersion
    @Environment(\.dismiss) private var dismiss

    @State private var slots: [ExpectedRepSlot] = []
    @State private var currentSlotIndex: Int = 1
    @State private var isRunning: Bool = false
    @State private var isInRestPhase: Bool = false

    // Monotonic uptime anchors (immune to system wall-clock shifts)
    @State private var repStartUptime: TimeInterval? = nil
    @State private var restStartUptime: TimeInterval? = nil
    @State private var lastToggleUptime: TimeInterval = 0
    @State private var latestRepElapsedMs: Int64 = 0
    @State private var tickState: LiveTimerTickOutput = LiveTimerTickOutput(
        phase: "swimming",
        formattedRepTime: "0.00",
        remainingRestMs: 30_000,
        formattedRemainingRest: "30.00",
        audioCue: "none",
        shouldAutoAdvance: false
    )

    @State private var completedRepsBySlot: [Int: Int64] = [:]
    @State private var earnedRestBySlot: [Int: Int64] = [:]
    @State private var splitsBySlot: [Int: [Int64]] = [:]
    @State private var lastSplitCumulativeMs: Int64 = 0
    @State private var skippedSlots: Set<Int> = []

    /// Minimum monotonic debounce interval (0.80s) to prevent wet-screen/water droplet double triggers.
    private let wetFingerDebounceSec: TimeInterval = 0.80
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    public init(store: L4NEAppStore, template: TemplateWithVersion) {
        self.store = store
        self.template = template
    }

    private var activeSlot: ExpectedRepSlot? {
        slots.first(where: { $0.slotIndex == currentSlotIndex })
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                // Top Protocol & Slot Status Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("L4NE PERFORMANCE · LIVE TIMER")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(L4NETheme.electricLime)
                            .tracking(1.4)
                        Text(template.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(L4NETheme.textPrimary)
                    }
                    Spacer()
                    Text("REP \(currentSlotIndex)/\(max(1, slots.count))")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(L4NETheme.cardSurface)
                        .foregroundStyle(L4NETheme.electricLime)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)

                // Giant High-Contrast Poolside Cockpit HUD
                if let slot = activeSlot {
                    VStack(spacing: 10) {
                        HStack {
                            Text("ROUND \(slot.roundIndex) · \(slot.distanceM ?? 50)M \(slot.strokeOrMovement.uppercased())")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.textSecondary)
                            Spacer()
                            Text(slot.restMode == .sendOff
                                 ? "SEND-OFF @ \(L4NEDurationFormatter.formatIntervalMs(slot.restOrSendoffMs))"
                                 : "REST \(L4NEDurationFormatter.formatIntervalMs(slot.restOrSendoffMs))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.electricLime)
                        }

                        // Primary Stopwatch Display
                        VStack(spacing: 2) {
                            Text(isInRestPhase ? "LAST REP SPLIT" : "ACTIVE REP STOPWATCH")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.textSecondary)

                            Text(tickState.formattedRepTime)
                                .font(.system(size: 62, weight: .black, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(isInRestPhase ? L4NETheme.textPrimary : L4NETheme.electricLime)
                                .minimumScaleFactor(0.65)
                        }
                        .padding(.vertical, 4)

                        // Deterministic Rest / Send-Off Countdown Display
                        VStack(spacing: 4) {
                            Text(slot.restMode == .sendOff ? "NEXT SEND-OFF DEPARTURE IN" : "REST COUNTDOWN REMAINING")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.textSecondary)

                            Text(tickState.formattedRemainingRest)
                                .font(.system(size: 38, weight: .black, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(countdownAccentColor)

                            if tickState.audioCue != "none" {
                                Text(cueBannerText(tickState.audioCue))
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(countdownAccentColor)
                                    .foregroundStyle(Color.black)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(L4NETheme.mutedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(16)
                    .background(L4NETheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isInRestPhase ? countdownAccentColor : L4NETheme.electricLime.opacity(0.6), lineWidth: 1.5)
                    )
                    .padding(.horizontal, 16)
                }

                // Giant Tactile Poolside Action Buttons (Debounced >= 0.80s)
                HStack(spacing: 12) {
                    if !isRunning {
                        Button {
                            startSwimmingCurrentRep()
                        } label: {
                            Label("START REP #\(currentSlotIndex)", systemImage: "play.fill")
                                .font(.system(size: 17, weight: .black, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(L4NETheme.electricLime)
                                .foregroundStyle(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    } else if !isInRestPhase {
                        Button {
                            recordIntermediateLapSplit()
                        } label: {
                            Label("LAP SPLIT", systemImage: "flag.checkered")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .frame(width: 112, height: 62)
                                .background(L4NETheme.cardSurface)
                                .foregroundStyle(L4NETheme.electricLime)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(L4NETheme.electricLime, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            touchWallFinishRep()
                        } label: {
                            Label("WALL / FINISH", systemImage: "hand.tap.fill")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(L4NETheme.signalGreen)
                                .foregroundStyle(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            departNextRepImmediately()
                        } label: {
                            Label("DEPART NEXT REP NOW", systemImage: "forward.end.fill")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(L4NETheme.electricLime)
                                .foregroundStyle(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        skipCurrentRep()
                    } label: {
                        Text("SKIP")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .frame(width: 72, height: 62)
                            .background(L4NETheme.mutedSurface)
                            .foregroundStyle(L4NETheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // Completed Live Splits Feed
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(slots) { slot in
                            if let ms = completedRepsBySlot[slot.slotIndex] {
                                HStack {
                                    Text("#\(slot.slotIndex) · \(slot.distanceM ?? 0)m")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.textSecondary)
                                    Spacer()
                                    Text(L4NEDurationFormatter.formatMs(ms))
                                        .font(.system(size: 15, weight: .black, design: .monospaced))
                                        .foregroundStyle(L4NETheme.electricLime)
                                    if let restMs = earnedRestBySlot[slot.slotIndex] {
                                        Text("Rest \(L4NEDurationFormatter.formatMs(restMs))")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(L4NETheme.signalGreen)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(L4NETheme.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .background(L4NETheme.background.ignoresSafeArea())
            .navigationTitle("Live Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish & Save") {
                        saveLiveSession()
                    }
                    .disabled(completedRepsBySlot.isEmpty)
                }
            }
            .onAppear {
                slots = (try? store.client.expandTemplateSlots(templateVersionId: template.activeVersion.id)) ?? []
                refreshTickState()
            }
            .onReceive(timer) { _ in
                guard isRunning else { return }
                refreshTickState()
            }
        }
    }

    private var countdownAccentColor: Color {
        switch tickState.audioCue {
        case "depart_now": return L4NETheme.signalGreen
        case "countdown_3_2_1": return L4NETheme.regressionRed
        case "five_sec_warning", "ten_sec_warning": return L4NETheme.warningAmber
        default: return L4NETheme.electricLime
        }
    }

    private func cueBannerText(_ cue: String) -> String {
        switch cue {
        case "ten_sec_warning": return "10 SECONDS TO DEPARTURE"
        case "five_sec_warning": return "5 SECONDS — FEET ON WALL"
        case "countdown_3_2_1": return "3 · 2 · 1 · TAKE YOUR MARK"
        case "depart_now": return "GO! DEPART NOW!"
        default: return ""
        }
    }

    private func passesDebounce() -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastToggleUptime < wetFingerDebounceSec {
            return false
        }
        lastToggleUptime = now
        return true
    }

    private func startSwimmingCurrentRep() {
        guard passesDebounce() else { return }
        let now = ProcessInfo.processInfo.systemUptime
        repStartUptime = now
        restStartUptime = nil
        latestRepElapsedMs = 0
        lastSplitCumulativeMs = 0
        isInRestPhase = false
        isRunning = true
        refreshTickState()
    }

    private func recordIntermediateLapSplit() {
        guard passesDebounce(), let start = repStartUptime else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let cumulativeMs = max(100, Int64((now - start) * 1000.0))
        let lapSegmentMs = max(100, cumulativeMs - lastSplitCumulativeMs)
        lastSplitCumulativeMs = cumulativeMs
        var currentSplits = splitsBySlot[currentSlotIndex] ?? []
        currentSplits.append(lapSegmentMs)
        splitsBySlot[currentSlotIndex] = currentSplits
    }

    private func touchWallFinishRep() {
        guard passesDebounce(), let start = repStartUptime else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsedMs = max(100, Int64((now - start) * 1000.0))
        latestRepElapsedMs = elapsedMs
        completedRepsBySlot[currentSlotIndex] = elapsedMs
        if var existingSplits = splitsBySlot[currentSlotIndex], !existingSplits.isEmpty {
            let finalSegment = max(100, elapsedMs - lastSplitCumulativeMs)
            existingSplits.append(finalSegment)
            splitsBySlot[currentSlotIndex] = existingSplits
        }

        if let slot = activeSlot {
            let earned = slot.restMode == .sendOff
                ? max(0, slot.restOrSendoffMs - elapsedMs)
                : max(0, slot.restOrSendoffMs)
            earnedRestBySlot[currentSlotIndex] = earned
        }

        if currentSlotIndex >= slots.count {
            // Final rep of the set completed!
            isRunning = false
            isInRestPhase = false
            refreshTickState()
            return
        }

        restStartUptime = now
        isInRestPhase = true
        refreshTickState()
    }

    private func departNextRepImmediately() {
        guard passesDebounce() else { return }
        advanceToNextRepAndSwim()
    }

    private func advanceToNextRepAndSwim() {
        if currentSlotIndex < slots.count {
            currentSlotIndex += 1
            let now = ProcessInfo.processInfo.systemUptime
            repStartUptime = now
            restStartUptime = nil
            latestRepElapsedMs = 0
            isInRestPhase = false
            isRunning = true
            refreshTickState()
        } else {
            isRunning = false
            isInRestPhase = false
        }
    }

    private func skipCurrentRep() {
        guard passesDebounce() else { return }
        skippedSlots.insert(currentSlotIndex)
        if currentSlotIndex < slots.count {
            currentSlotIndex += 1
            isRunning = false
            isInRestPhase = false
            repStartUptime = nil
            restStartUptime = nil
            latestRepElapsedMs = 0
            refreshTickState()
        }
    }

    private func refreshTickState() {
        guard let slot = activeSlot else { return }
        let now = ProcessInfo.processInfo.systemUptime

        let repMs: Int64
        let restMs: Int64?
        if isInRestPhase {
            repMs = latestRepElapsedMs
            if let rStart = restStartUptime {
                restMs = max(0, Int64((now - rStart) * 1000.0))
            } else {
                restMs = 0
            }
        } else if isRunning, let start = repStartUptime {
            repMs = max(0, Int64((now - start) * 1000.0))
            restMs = nil
        } else {
            repMs = completedRepsBySlot[currentSlotIndex] ?? 0
            restMs = nil
        }

        if let evaluated = try? store.client.computeLiveTimerTick(
            LiveTimerTickInput(
                restMode: slot.restMode,
                restOrSendoffMs: slot.restOrSendoffMs,
                repElapsedMs: repMs,
                restElapsedMs: restMs
            )
        ) {
            tickState = evaluated
            if isInRestPhase && evaluated.shouldAutoAdvance {
                advanceToNextRepAndSwim()
            }
        }
    }

    private func saveLiveSession() {
        let reps: [RepInput] = slots.compactMap { slot in
            if skippedSlots.contains(slot.slotIndex) {
                return RepInput(slotIndex: slot.slotIndex, durationMs: nil, isSkipped: true)
            }
            guard let ms = completedRepsBySlot[slot.slotIndex] else { return nil }
            return RepInput(
                slotIndex: slot.slotIndex,
                durationMs: ms,
                splitsMs: splitsBySlot[slot.slotIndex] ?? []
            )
        }
        guard !reps.isEmpty else { return }
        store.logSession(
            LogSessionInput(
                templateId: template.id,
                templateVersionId: template.activeVersion.id,
                performedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
                poolLengthM: template.poolLengthM,
                notes: "Recorded via L4NE Live Poolside Companion (v1.1)",
                reps: reps
            )
        )
        dismiss()
    }
}
