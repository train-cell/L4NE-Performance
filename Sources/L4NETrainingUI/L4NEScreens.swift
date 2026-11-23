import SwiftUI
#if canImport(L4NETrainingCore)
import L4NETrainingCore
#endif

/// Root container view providing navigation across the 5 primary tabs (covering all 8 MVP screens).
public struct L4NERootView: View {
    @StateObject private var store: L4NEAppStore

    public init(store: L4NEAppStore? = nil) {
        _store = StateObject(wrappedValue: store ?? L4NEAppStore())
    }

    public var body: some View {
        TabView {
            DashboardView(store: store)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.needle.fill")
                }

            TemplatesLibraryView(store: store)
                .tabItem {
                    Label("Templates", systemImage: "square.stack.3d.up.fill")
                }

            DailyTimelineView(store: store)
                .tabItem {
                    Label("Timeline", systemImage: "calendar.day.timeline.left")
                }

            WorkoutImportView(store: store)
                .tabItem {
                    Label("HealthKit", systemImage: "applewatch.radiowaves.left.and.right")
                }

            SettingsDataView(store: store)
                .tabItem {
                    Label("Data", systemImage: "externaldrive.fill.badge.checkmark")
                }
        }
        .tint(L4NETheme.electricLime)
        .preferredColorScheme(.dark)
    }
}

// MARK: - 1. Dashboard Screen

public struct DashboardView: View {
    @ObservedObject var store: L4NEAppStore
    @State private var selectedTemplateForLogging: TemplateWithVersion?

    public init(store: L4NEAppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header bar
                    HStack {
                        L4NEBrandWordmark(subtitle: "TRAINING · BUILT TO OUTPERFORM")
                        Spacer()
                        Text("v\(L4NECoreClient.engineVersion)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(L4NETheme.mutedSurface)
                            .foregroundStyle(L4NETheme.electricLime)
                            .clipShape(Capsule())
                    }

                    // Key Deterministic Metrics Row
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        L4NEMetricTile(
                            title: "Active Templates",
                            value: "\(store.templates.count)",
                            subtitle: "Swimming & Finswimming",
                            accentColor: L4NETheme.electricLime
                        )

                        L4NEMetricTile(
                            title: "Logged Sessions",
                            value: "\(store.recentSessions.count)",
                            subtitle: "100% Local-First SQLite",
                            accentColor: L4NETheme.textPrimary
                        )
                    }

                    // Quick Start Logging Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("QUICK SESSION LOGGING")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                            .tracking(1.2)

                        ForEach(store.templates) { tpl in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(tpl.name)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(L4NETheme.textPrimary)

                                        Text("v\(tpl.activeVersion.versionNumber)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(L4NETheme.mutedSurface)
                                            .foregroundStyle(L4NETheme.electricLime)
                                            .clipShape(Capsule())
                                    }

                                    Text("\(tpl.sportCategory.displayTitle) · \(tpl.activeVersion.totalReps) reps · \(tpl.activeVersion.totalDistanceM ?? 0)m · \(tpl.activeVersion.isHomogeneous ? "Homogeneous" : "Pyramid / Compound")")
                                        .font(.system(size: 12))
                                        .foregroundStyle(L4NETheme.textSecondary)
                                }
                                Spacer()
                                Button {
                                    selectedTemplateForLogging = tpl
                                } label: {
                                    Text("LOG SET")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(L4NETheme.electricLime)
                                        .foregroundStyle(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(14)
                            .background(L4NETheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(L4NETheme.border, lineWidth: 1)
                            )
                        }
                    }

                    // Recent Sessions & Improvements
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RECENT DETERMINISTIC SESSIONS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                            .tracking(1.2)

                        ForEach(store.recentSessions) { session in
                            NavigationLink {
                                TemplateAnalyticsView(store: store, templateId: session.templateId)
                            } label: {
                                SessionSummaryCard(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(L4NETheme.background.ignoresSafeArea())
            .sheet(item: $selectedTemplateForLogging) { template in
                SessionLoggingView(store: store, template: template)
            }
        }
    }
}

struct SessionSummaryCard: View {
    let session: SessionWithReps

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.templateName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(L4NETheme.textPrimary)
                Spacer()
                Text("v\(session.templateVersionNumber)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(L4NETheme.electricLime)
            }

            HStack(spacing: 16) {
                if let avg = session.metrics.avgDurationMs {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AVG REP")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                        Text(L4NEDurationFormatter.formatMs(avg))
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundStyle(L4NETheme.electricLime)
                    }
                }

                if let pace = session.metrics.avgPaceMsPer100m {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PACE / 100M")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                        Text(L4NEDurationFormatter.formatPacePer100m(pace))
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundStyle(L4NETheme.textPrimary)
                    }
                }

                if let cv = session.metrics.consistencyCvPct {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CV% CONSISTENCY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                        Text(String(format: "%.2f%%", cv))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.signalGreen)
                    }
                }

                if let fatigue = session.metrics.fatigueIndexPct {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FATIGUE SPLIT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                        Text(String(format: "%+.2f%%", fatigue))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(fatigue <= 0 ? L4NETheme.signalGreen : L4NETheme.warningAmber)
                    }
                }
            }
        }
        .padding(14)
        .background(L4NETheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(L4NETheme.border, lineWidth: 1)
        )
    }
}

// MARK: - 2. Templates Library & Builder (Homogeneous + Pyramid / Compound Sets)

public struct TemplatesLibraryView: View {
    @ObservedObject var store: L4NEAppStore
    @State private var showCreateSheet = false

    public init(store: L4NEAppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(store.templates) { tpl in
                        NavigationLink {
                            TemplateAnalyticsView(store: store, templateId: tpl.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(tpl.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(L4NETheme.textPrimary)
                                    Spacer()
                                    Text(tpl.activeVersion.isHomogeneous ? "HOMOGENEOUS" : "PYRAMID / COMPOUND")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(L4NETheme.mutedSurface)
                                        .foregroundStyle(L4NETheme.electricLime)
                                        .clipShape(Capsule())
                                }

                                Text("\(tpl.sportCategory.displayTitle) · Πισίνα \(tpl.poolLengthM ?? 50)m · Έκδοση v\(tpl.activeVersion.versionNumber) · \(tpl.totalSessionsCount) εκτελέσεις")
                                    .font(.system(size: 12))
                                    .foregroundStyle(L4NETheme.textSecondary)

                                if !tpl.activeVersion.equipment.isEmpty {
                                    HStack(spacing: 6) {
                                        ForEach(tpl.activeVersion.equipment, id: \.self) { eq in
                                            Text(eq.uppercased())
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(L4NETheme.background)
                                                .foregroundStyle(L4NETheme.textSecondary)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .background(L4NETheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(L4NETheme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(L4NETheme.background.ignoresSafeArea())
            .navigationTitle("Templates Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("New Template", systemImage: "plus.circle.fill")
                            .foregroundStyle(L4NETheme.electricLime)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                TemplateBuilderSheet(store: store)
            }
        }
    }
}

public struct TemplateBuilderSheet: View {
    @ObservedObject var store: L4NEAppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var sport: SportCategory = .finswimming
    @State private var poolLengthM: Int = 50
    @State private var rounds: Int = 1
    @State private var selectedEquipment: Set<String> = ["monofin", "snorkel"]
    @State private var blocks: [TemplateBlockInput] = [
        TemplateBlockInput(
            repeatCount: 8,
            distanceM: 50,
            strokeOrMovement: "surface",
            restMode: .fixedRest,
            restOrSendoffMs: 30_000
        )
    ]

    private let availableEquipment = ["monofin", "bifins", "snorkel", "paddles", "pullbuoy", "kickboard"]

    public var body: some View {
        NavigationStack {
            Form {
                Section("Ταυτότητα Πρωτοκόλλου") {
                    TextField("Όνομα (π.χ. 8×50m Επιφάνεια ή Πυραμίδα)", text: $name)
                    Picker("Άθλημα", selection: $sport) {
                        ForEach(SportCategory.allCases, id: \.self) { cat in
                            Text(cat.displayTitle).tag(cat)
                        }
                    }
                    Picker("Μήκος Πισίνας", selection: $poolLengthM) {
                        Text("25m").tag(25)
                        Text("50m").tag(50)
                    }
                    Stepper("Κύκλοι (Rounds): \(rounds)", value: $rounds, in: 1...20)
                }

                Section("Εξοπλισμός (Equipment)") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(availableEquipment, id: \.self) { item in
                            let isSelected = selectedEquipment.contains(item)
                            Button {
                                if isSelected {
                                    selectedEquipment.remove(item)
                                } else {
                                    selectedEquipment.insert(item)
                                }
                            } label: {
                                Text(item.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? L4NETheme.electricLime : L4NETheme.mutedSurface)
                                    .foregroundStyle(isSelected ? Color.black : L4NETheme.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Βήματα / Blocks (Απλό Σετ ή Πυραμίδα)") {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { idx, block in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Block #\(idx + 1): \(block.repeatCount) × \(block.distanceM ?? 50)m (\(block.strokeOrMovement))")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                Spacer()
                                if blocks.count > 1 {
                                    Button(role: .destructive) {
                                        blocks.remove(at: idx)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                            Text("\(block.restMode.displayTitle): \(L4NEDurationFormatter.formatIntervalMs(block.restOrSendoffMs))")
                                .font(.system(size: 11))
                                .foregroundStyle(L4NETheme.textSecondary)
                        }
                    }

                    Button("Προσθήκη Βήματος Πυραμίδας (+100m)") {
                        blocks.append(
                            TemplateBlockInput(
                                repeatCount: 1,
                                distanceM: 100,
                                strokeOrMovement: sport == .finswimming ? "surface" : "freestyle",
                                restMode: .fixedRest,
                                restOrSendoffMs: 30_000
                            )
                        )
                    }
                }
            }
            .navigationTitle("Create Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Protocol") {
                        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty
                            ? "Custom L4NE Protocol"
                            : name
                        store.createTemplate(
                            CreateTemplateInput(
                                name: finalName,
                                sportCategory: sport,
                                poolLengthM: poolLengthM,
                                environment: .pool,
                                rounds: rounds,
                                roundRestMs: 0,
                                equipment: Array(selectedEquipment).sorted(),
                                blocks: blocks
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 3. Session Logging Screen with Athletic Centisecond Numpad

public struct SessionLoggingView: View {
    @ObservedObject var store: L4NEAppStore
    public let template: TemplateWithVersion
    @Environment(\.dismiss) private var dismiss

    @State private var slots: [ExpectedRepSlot] = []
    @State private var currentSlotIndex: Int = 1
    @State private var rawDigitsBySlot: [Int: String] = [:]
    @State private var parsedMsBySlot: [Int: Int64] = [:]
    @State private var sessionNotes: String = ""

    public init(store: L4NEAppStore, template: TemplateWithVersion) {
        self.store = store
        self.template = template
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Slot horizontal strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(slots) { slot in
                            let isCurrent = slot.slotIndex == currentSlotIndex
                            let recordedMs = parsedMsBySlot[slot.slotIndex]
                            Button {
                                currentSlotIndex = slot.slotIndex
                            } label: {
                                VStack(spacing: 3) {
                                    Text("#\(slot.slotIndex) · \(slot.distanceM ?? 0)m")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    Text(recordedMs.map { L4NEDurationFormatter.formatMs($0) } ?? "--.--")
                                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isCurrent ? L4NETheme.electricLime : L4NETheme.cardSurface)
                                .foregroundStyle(isCurrent ? Color.black : L4NETheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Active Slot Display Card
                if let activeSlot = slots.first(where: { $0.slotIndex == currentSlotIndex }) {
                    VStack(spacing: 8) {
                        Text("REP #\(activeSlot.slotIndex) OF \(slots.count) · ROUND \(activeSlot.roundIndex)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)

                        Text("\(activeSlot.distanceM ?? 0)m \(activeSlot.strokeOrMovement.uppercased())")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(L4NETheme.textPrimary)

                        let raw = rawDigitsBySlot[currentSlotIndex] ?? ""
                        let formatted = (try? store.client.parseAthleticNumpad(digits: raw).formattedDisplay) ?? "00.00"

                        Text(formatted)
                            .font(.system(size: 46, weight: .black, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(L4NETheme.electricLime)
                            .padding(.vertical, 4)

                        // Live Send-off Actual Rest & Running Average feedback
                        HStack(spacing: 16) {
                            if activeSlot.restMode == .sendOff, let dur = parsedMsBySlot[currentSlotIndex] {
                                let actualRest = max(0, activeSlot.restOrSendoffMs - dur)
                                Text("ACTUAL REST: \(L4NEDurationFormatter.formatMs(actualRest))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(L4NETheme.signalGreen)
                            } else {
                                Text("REST PROTOCOL: \(L4NEDurationFormatter.formatIntervalMs(activeSlot.restOrSendoffMs))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(L4NETheme.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(L4NETheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }

                Spacer()

                // Custom Athletic Centisecond Numpad (Digits only -> SS.cc / M:SS.cc)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button("SAME AS PREV") {
                            if currentSlotIndex > 1,
                               let prevDigits = rawDigitsBySlot[currentSlotIndex - 1] {
                                applyDigits(prevDigits)
                            }
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(L4NETheme.mutedSurface)
                        .foregroundStyle(L4NETheme.electricLime)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("CLEAR") {
                            rawDigitsBySlot[currentSlotIndex] = nil
                            parsedMsBySlot[currentSlotIndex] = nil
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(L4NETheme.mutedSurface)
                        .foregroundStyle(L4NETheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    let rows = [
                        ["1", "2", "3"],
                        ["4", "5", "6"],
                        ["7", "8", "9"],
                        ["⌫", "0", "NEXT ⏎"]
                    ]

                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.self) { key in
                                Button {
                                    handleNumpadKey(key)
                                } label: {
                                    Text(key)
                                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(key == "NEXT ⏎" ? L4NETheme.electricLime : L4NETheme.cardSurface)
                                        .foregroundStyle(key == "NEXT ⏎" ? Color.black : L4NETheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(L4NETheme.background.ignoresSafeArea())
            .navigationTitle(template.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Session") {
                        saveLoggedSession()
                    }
                    .disabled(parsedMsBySlot.isEmpty)
                }
            }
            .onAppear {
                slots = (try? store.client.expandTemplateSlots(templateVersionId: template.activeVersion.id)) ?? []
            }
        }
    }

    private func handleNumpadKey(_ key: String) {
        var current = rawDigitsBySlot[currentSlotIndex] ?? ""
        switch key {
        case "⌫":
            if !current.isEmpty {
                current.removeLast()
                applyDigits(current)
            }
        case "NEXT ⏎":
            if currentSlotIndex < slots.count {
                currentSlotIndex += 1
            } else {
                saveLoggedSession()
            }
        default:
            if current.count < 6 {
                current.append(key)
                applyDigits(current)
            }
        }
    }

    private func applyDigits(_ digits: String) {
        rawDigitsBySlot[currentSlotIndex] = digits
        if let parsed = try? store.client.parseAthleticNumpad(digits: digits) {
            parsedMsBySlot[currentSlotIndex] = parsed.durationMs
        } else {
            parsedMsBySlot[currentSlotIndex] = nil
        }
    }

    private func saveLoggedSession() {
        let repInputs: [RepInput] = slots.compactMap { slot in
            guard let ms = parsedMsBySlot[slot.slotIndex] else { return nil }
            return RepInput(slotIndex: slot.slotIndex, durationMs: ms)
        }
        guard !repInputs.isEmpty else { return }
        store.logSession(
            LogSessionInput(
                templateId: template.id,
                templateVersionId: template.activeVersion.id,
                performedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
                poolLengthM: template.poolLengthM,
                notes: sessionNotes.isEmpty ? nil : sessionNotes,
                reps: repInputs
            )
        )
        dismiss()
    }
}

// MARK: - 4. Template Analytics & Slot-by-Slot Comparison Screen

public struct TemplateAnalyticsView: View {
    @ObservedObject var store: L4NEAppStore
    public let templateId: String
    @State private var report: TemplateAnalyticsReport?

    public init(store: L4NEAppStore, templateId: String) {
        self.store = store
        self.templateId = templateId
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let report {
                    Text(report.templateName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(L4NETheme.textPrimary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        L4NEMetricTile(
                            title: "Personal Best Pace",
                            value: report.personalBestPaceMsPer100m.map { L4NEDurationFormatter.formatPacePer100m($0) } ?? "--",
                            subtitle: "Active Protocol v\(report.activeVersionNumber)",
                            accentColor: L4NETheme.electricLime
                        )

                        L4NEMetricTile(
                            title: "Best Single Rep",
                            value: report.personalBestRepDurationMs.map { L4NEDurationFormatter.formatMs($0) } ?? "Compound Set",
                            subtitle: "Total Sessions: \(report.totalSessions)",
                            accentColor: L4NETheme.signalGreen
                        )
                    }

                    // Latest vs Previous Session Comparison
                    if let cmp = report.latestVsPrevious {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("LATEST VS PREVIOUS SESSION")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(L4NETheme.textSecondary)
                                Spacer()
                                Text(String(format: "%+.2f%% IMPROVEMENT", cmp.totalImprovementPct))
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundStyle(cmp.totalImprovementPct >= 0 ? L4NETheme.signalGreen : L4NETheme.regressionRed)
                            }

                            if let warning = cmp.protocolWarning {
                                Text(warning)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(L4NETheme.warningAmber)
                            }

                            ForEach(cmp.slotDeltas) { delta in
                                HStack {
                                    Text("Rep #\(delta.slotIndex) (\(delta.distanceM ?? 0)m)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.textSecondary)
                                    Spacer()
                                    if let cur = delta.currentDurationMs, let base = delta.baselineDurationMs {
                                        Text("\(L4NEDurationFormatter.formatMs(base)) → \(L4NEDurationFormatter.formatMs(cur))")
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundStyle(L4NETheme.textPrimary)
                                    }
                                    if let d = delta.deltaMs {
                                        Text(L4NEDurationFormatter.formatMs(d))
                                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(d <= 0 ? L4NETheme.signalGreen : L4NETheme.regressionRed)
                                            .frame(width: 70, alignment: .trailing)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(14)
                        .background(L4NETheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Observational Health Context Section (Correlation, never causation)
                    if !report.healthCorrelations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HEALTH CONTEXT (OBSERVATIONAL CORRELATION)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.textSecondary)

                            ForEach(report.healthCorrelations) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(note.dateIso)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(L4NETheme.electricLime)
                                        Spacer()
                                        if let pace = note.avgPaceMsPer100m {
                                            Text(L4NEDurationFormatter.formatPacePer100m(pace))
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundStyle(L4NETheme.textPrimary)
                                        }
                                    }
                                    Text(note.observationalNote)
                                        .font(.system(size: 12))
                                        .foregroundStyle(L4NETheme.textSecondary)
                                }
                                .padding(12)
                                .background(L4NETheme.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(L4NETheme.background.ignoresSafeArea())
        .navigationTitle("Deterministic Analytics")
        .onAppear {
            report = try? store.client.getTemplateAnalytics(templateId: templateId)
        }
    }
}

// MARK: - 5. Daily Training Timeline & Health Context Screen

public struct DailyTimelineView: View {
    @ObservedObject var store: L4NEAppStore

    public init(store: L4NEAppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let timeline = store.currentTimeline {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            L4NEMetricTile(
                                title: "Daily Volume",
                                value: String(format: "%.0f m", timeline.totalVolumeDistanceM),
                                subtitle: timeline.dateIso,
                                accentColor: L4NETheme.electricLime
                            )

                            L4NEMetricTile(
                                title: "Total Duration",
                                value: L4NEDurationFormatter.formatIntervalMs(timeline.totalDurationMs),
                                subtitle: "\(timeline.workouts.count) Workouts · \(timeline.standaloneAndLinkedSessions.count) Sets",
                                accentColor: L4NETheme.textPrimary
                            )
                        }

                        if let health = timeline.healthSnapshot {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("APPLE HEALTH RECOVERY CONTEXT (\(health.dateIso))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(L4NETheme.electricLime)
                                Text("Sleep: \((health.sleepDurationMinutes ?? 0) / 60)h \((health.sleepDurationMinutes ?? 0) % 60)m · HRV: \(String(format: "%.1f", health.hrvSdnnMs ?? 0)) ms · RHR: \(String(format: "%.0f", health.restingHrBpm ?? 0)) bpm")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(L4NETheme.textPrimary)
                                Text(health.sourceSummary ?? "Apple HealthKit")
                                    .font(.system(size: 11))
                                    .foregroundStyle(L4NETheme.textSecondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(L4NETheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        ForEach(timeline.workouts) { w in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(w.sportCategory.displayTitle.uppercased())
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundStyle(L4NETheme.electricLime)
                                    Spacer()
                                    Text(w.externalSourceName ?? w.sourceType.rawValue)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.signalGreen)
                                }
                                Text("\(String(format: "%.0f m", w.totalDistanceM ?? 0)) · Πισίνα \(w.poolLengthM ?? 50)m · Avg HR \(String(format: "%.0f bpm", w.avgHeartRateBpm ?? 0))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(L4NETheme.textPrimary)
                            }
                            .padding(14)
                            .background(L4NETheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        ForEach(timeline.standaloneAndLinkedSessions) { s in
                            SessionSummaryCard(session: s)
                        }
                    }
                }
                .padding(16)
            }
            .background(L4NETheme.background.ignoresSafeArea())
            .navigationTitle("Daily Timeline")
        }
    }
}

// MARK: - 6. Apple HealthKit Workout Import & Deterministic Matching Screen

public struct WorkoutImportView: View {
    @ObservedObject var store: L4NEAppStore

    public init(store: L4NEAppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("APPLE HEALTHKIT INTEGRATION (READ-ONLY v1.0)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.electricLime)
                        Text("Status: \(store.healthKitStatus.rawValue)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(L4NETheme.textPrimary)

                        HStack(spacing: 10) {
                            Button("Connect HealthKit") {
                                Task {
                                    store.healthKitStatus = await store.healthKitAdapter.requestReadAuthorization()
                                }
                            }
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(L4NETheme.electricLime)
                            .foregroundStyle(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button("Simulate Watch Import") {
                                store.importSampleAppleWatchWorkout()
                            }
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(L4NETheme.mutedSurface)
                            .foregroundStyle(L4NETheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(14)
                    .background(L4NETheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    ForEach(store.workouts) { workout in
                        let candidates = (try? store.client.matchWorkoutTemplates(workoutId: workout.id)) ?? []
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(workout.externalSourceName ?? "Apple Watch") · \(String(format: "%.0f m", workout.totalDistanceM ?? 0))")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(L4NETheme.textPrimary)

                            Text("DETERMINISTIC TEMPLATE CANDIDATES:")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.textSecondary)

                            ForEach(candidates) { cand in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cand.templateName)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(L4NETheme.textPrimary)
                                        Text(cand.deterministicReasons.joined(separator: " · "))
                                            .font(.system(size: 11))
                                            .foregroundStyle(L4NETheme.textSecondary)
                                    }
                                    Spacer()
                                    Text("Score \(cand.compatibilityScore)")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundStyle(L4NETheme.electricLime)
                                }
                                .padding(8)
                                .background(L4NETheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(14)
                        .background(L4NETheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .background(L4NETheme.background.ignoresSafeArea())
            .navigationTitle("Workout Import")
        }
    }
}

// MARK: - 7. Settings, Local-First Backup & Legal Screen

public struct SettingsDataView: View {
    @ObservedObject var store: L4NEAppStore

    public init(store: L4NEAppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        L4NEBrandWordmark(subtitle: "LOCAL-FIRST · ZERO AI · ZERO CLOUD")
                        Text("Database: \(store.client.databasePath)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                            .padding(.top, 4)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(L4NETheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 12) {
                        Button("Export JSON Backup") {
                            store.exportJSONBackup()
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(L4NETheme.electricLime)
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button("Export Sessions CSV") {
                            store.exportCSV()
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(L4NETheme.cardSurface)
                        .foregroundStyle(L4NETheme.electricLime)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let preview = store.lastExportPreview {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EXPORT OUTPUT PREVIEW")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.electricLime)
                            Text(String(preview.prefix(1200)))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(L4NETheme.textPrimary)
                        }
                        .padding(12)
                        .background(L4NETheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
            }
            .background(L4NETheme.background.ignoresSafeArea())
            .navigationTitle("Data & Privacy")
        }
    }
}
