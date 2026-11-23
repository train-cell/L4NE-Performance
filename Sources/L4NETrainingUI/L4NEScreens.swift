import SwiftUI
#if canImport(Charts)
import Charts
#endif
#if canImport(L4NETrainingCore)
import L4NETrainingCore
#endif

/// Root container view providing navigation across the 5 primary tabs (covering all 8 v1.1 screens).
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

// MARK: - 1. Dashboard Screen (v1.1 with Fast Numpad + Live Poolside Timer + Multi-Sport Filter)

public struct DashboardView: View {
    @ObservedObject var store: L4NEAppStore
    @State private var selectedTemplateForNumpad: TemplateWithVersion?
    @State private var selectedTemplateForLiveTimer: TemplateWithVersion?

    public init(store: L4NEAppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Brand Header
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

                    if let status = store.lastStatusBanner {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(L4NETheme.electricLime)
                            Text(status)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(L4NETheme.textPrimary)
                            Spacer()
                        }
                        .padding(10)
                        .background(L4NETheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Multi-Sport Filter Strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            SportFilterPill(
                                title: "ALL SPORTS",
                                isSelected: store.selectedSportFilter == nil
                            ) {
                                store.selectedSportFilter = nil
                            }

                            ForEach(SportCategory.allCases, id: \.self) { cat in
                                SportFilterPill(
                                    title: cat.displayTitle.uppercased(),
                                    isSelected: store.selectedSportFilter == cat
                                ) {
                                    store.selectedSportFilter = cat
                                }
                            }
                        }
                    }

                    // Deterministic Metrics Summary
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        L4NEMetricTile(
                            title: "Active Protocols",
                            value: "\(store.filteredTemplates.count)",
                            subtitle: "SHA-256 Versioned",
                            accentColor: L4NETheme.electricLime
                        )

                        L4NEMetricTile(
                            title: "Logged Sessions",
                            value: "\(store.recentSessions.count)",
                            subtitle: "Local-First SQLite v2",
                            accentColor: L4NETheme.textPrimary
                        )
                    }

                    // Quick Launch: Post-Workout Numpad OR Live Poolside Companion (v1.1)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("START TRAINING OR LOG PROTOCOL")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                            .tracking(1.2)

                        ForEach(store.filteredTemplates) { tpl in
                            VStack(alignment: .leading, spacing: 10) {
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

                                        Text("\(tpl.sportCategory.displayTitle) · \(tpl.activeVersion.totalReps) reps · \(tpl.activeVersion.totalDistanceM.map { "\($0)m · " } ?? "")\(tpl.activeVersion.isHomogeneous ? "Homogeneous" : "Pyramid / Compound")")
                                            .font(.system(size: 12))
                                            .foregroundStyle(L4NETheme.textSecondary)
                                    }
                                    Spacer()
                                }

                                HStack(spacing: 10) {
                                    Button {
                                        selectedTemplateForNumpad = tpl
                                    } label: {
                                        Label("FAST NUMPAD LOG", systemImage: "number.square.fill")
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(L4NETheme.electricLime)
                                            .foregroundStyle(Color.black)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        selectedTemplateForLiveTimer = tpl
                                    } label: {
                                        Label("LIVE TIMER", systemImage: "stopwatch.fill")
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(L4NETheme.mutedSurface)
                                            .foregroundStyle(L4NETheme.electricLime)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
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

                    // Recent Deterministic Sessions
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
            .sheet(item: $selectedTemplateForNumpad) { template in
                SessionLoggingView(store: store, template: template)
            }
            .sheet(item: $selectedTemplateForLiveTimer) { template in
                LivePoolsideTimerView(store: store, template: template)
            }
        }
    }
}

struct SportFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? L4NETheme.electricLime : L4NETheme.cardSurface)
                .foregroundStyle(isSelected ? Color.black : L4NETheme.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? L4NETheme.electricLime : L4NETheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
                if session.exportedExternalUuid != nil {
                    Text("HK EXPORTED")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(L4NETheme.mutedSurface)
                        .foregroundStyle(L4NETheme.signalGreen)
                        .clipShape(Capsule())
                }
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

                if let tonnage = session.metrics.totalTonnageKg {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TONNAGE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                        Text(String(format: "%.0f kg", tonnage))
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundStyle(L4NETheme.electricLime)
                    }
                }

                if let oneRm = session.metrics.bestEstimated1RmKg {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EST 1RM")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                        Text(String(format: "%.1f kg", oneRm))
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundStyle(L4NETheme.signalGreen)
                    }
                }

                if let bestAttempt = session.metrics.bestAttemptM {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BEST ATTEMPT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)
                        Text(String(format: "%.2f m", bestAttempt))
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundStyle(L4NETheme.electricLime)
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

// MARK: - 2. Templates Library, Complete Block Editor & Protocol Versioning Sheet

public struct TemplatesLibraryView: View {
    @ObservedObject var store: L4NEAppStore
    @State private var searchText: String = ""
    @State private var showCreateSheet = false
    @State private var templateToEdit: TemplateWithVersion?

    public init(store: L4NEAppStore) {
        self.store = store
    }

    private var displayedTemplates: [TemplateWithVersion] {
        store.filteredTemplates.filter { tpl in
            searchText.trimmingCharacters(in: .whitespaces).isEmpty
                || tpl.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        TextField("Αναζήτηση template...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        Toggle("Archived", isOn: $store.includeArchivedTemplates)
                            .labelsHidden()
                            .onChange(of: store.includeArchivedTemplates) { _, _ in
                                store.refreshAll()
                            }
                    }

                    ForEach(displayedTemplates) { tpl in
                        VStack(alignment: .leading, spacing: 10) {
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

                                    Text("\(tpl.sportCategory.displayTitle) · \(tpl.poolLengthM.map { "Πισίνα \($0)m · " } ?? "")\(tpl.folderTag.map { "[\($0)] · " } ?? "")Έκδοση v\(tpl.activeVersion.versionNumber) · \(tpl.totalSessionsCount) εκτελέσεις")
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
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 12) {
                                Button {
                                    templateToEdit = tpl
                                } label: {
                                    Label("Edit / Versions (v\(tpl.activeVersion.versionNumber))", systemImage: "slider.horizontal.3")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.electricLime)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    store.toggleTemplateArchived(tpl)
                                } label: {
                                    Label(tpl.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.textSecondary)
                                }
                                .buttonStyle(.plain)
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
                TemplateBuilderSheet(store: store, existingTemplate: nil)
            }
            .sheet(item: $templateToEdit) { tpl in
                TemplateBuilderSheet(store: store, existingTemplate: tpl)
            }
        }
    }
}

public struct TemplateBuilderSheet: View {
    @ObservedObject var store: L4NEAppStore
    public let existingTemplate: TemplateWithVersion?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var folderTag: String = "Race Pace / Taper"
    @State private var sport: SportCategory = .finswimming
    @State private var poolLengthM: Int = 50
    @State private var rounds: Int = 1
    @State private var roundRestSeconds: Int = 0
    @State private var selectedEquipment: Set<String> = ["monofin", "snorkel"]
    @State private var notes: String = ""
    @State private var blocks: [TemplateBlockInput] = [
        TemplateBlockInput(
            repeatCount: 8,
            distanceM: 50,
            strokeOrMovement: "surface",
            restMode: .fixedRest,
            restOrSendoffMs: 30_000
        )
    ]
    @State private var versionHistory: [TemplateVersion] = []

    private let availableEquipment = [
        "monofin", "bifins", "snorkel", "paddles", "pullbuoy", "kickboard", "parachute", "barbell", "spikes"
    ]

    public init(store: L4NEAppStore, existingTemplate: TemplateWithVersion? = nil) {
        self.store = store
        self.existingTemplate = existingTemplate
    }

    public var body: some View {
        NavigationStack {
            Form {
                if existingTemplate == nil {
                    Section("1-Tap Multi-Sport Presets") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button("8×50m Monofin") { applyPreset(.monofin8x50) }
                                Button("Bifins Pyramid") { applyPreset(.bifinsPyramid) }
                                Button("4×[2×50+100] Send-Off") { applyPreset(.compoundSendOff) }
                                Button("Track 6×200m") { applyPreset(.track6x200) }
                                Button("Field Long Jump") { applyPreset(.fieldLongJump) }
                                Button("Gym 5×5 Squat") { applyPreset(.gymSquat5x5) }
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                    }
                }

                Section("Ταυτότητα Πρωτοκόλλου") {
                    TextField("Όνομα Πρωτοκόλλου", text: $name)
                    TextField("Φάκελος / Macrocycle (π.χ. Race Pace, Aerobic Base)", text: $folderTag)
                    if existingTemplate == nil {
                        Picker("Άθλημα", selection: $sport) {
                            ForEach(SportCategory.allCases, id: \.self) { cat in
                                Text(cat.displayTitle).tag(cat)
                            }
                        }
                    }
                    if sport == .swimming || sport == .finswimming {
                        Picker("Μήκος Πισίνας", selection: $poolLengthM) {
                            Text("25m").tag(25)
                            Text("50m").tag(50)
                        }
                    }
                    Stepper("Κύκλοι (Rounds): \(rounds)", value: $rounds, in: 1...30)
                    Stepper("Διάλειμμα μεταξύ Κύκλων: \(roundRestSeconds)s", value: $roundRestSeconds, in: 0...600, step: 15)
                    TextField("Σημειώσεις Πρωτοκόλλου", text: $notes)
                }

                Section("Εξοπλισμός (Equipment)") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 8) {
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
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
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

                Section("Βήματα / Blocks (Πλήρης Επεξεργασία)") {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { idx, _ in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("BLOCK #\(idx + 1)")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundStyle(L4NETheme.electricLime)
                                Spacer()
                                if blocks.count > 1 {
                                    Button(role: .destructive) {
                                        blocks.remove(at: idx)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }

                            Stepper("Επαναλήψεις: \(blocks[idx].repeatCount)", value: $blocks[idx].repeatCount, in: 1...100)

                            if blocks[idx].recordKind == .timedDistance {
                                Stepper(
                                    "Απόσταση: \(blocks[idx].distanceM ?? 50)m",
                                    value: Binding(
                                        get: { blocks[idx].distanceM ?? 50 },
                                        set: { blocks[idx].distanceM = $0 }
                                    ),
                                    in: 15...5000,
                                    step: 25
                                )
                            }

                            Picker("Στυλ / Κίνηση", selection: $blocks[idx].strokeOrMovement) {
                                ForEach(sport.availableMovements, id: \.self) { mov in
                                    Text(mov.uppercased()).tag(mov)
                                }
                            }

                            Picker("Τύπος Διαλείμματος", selection: $blocks[idx].restMode) {
                                ForEach(RestMode.allCases, id: \.self) { mode in
                                    Text(mode.displayTitle).tag(mode)
                                }
                            }

                            Stepper(
                                "\(blocks[idx].restMode == .sendOff ? "Send-Off" : "Rest"): \(Int(blocks[idx].restOrSendoffMs / 1000))s",
                                value: Binding(
                                    get: { Int(blocks[idx].restOrSendoffMs / 1000) },
                                    set: { blocks[idx].restOrSendoffMs = Int64($0) * 1000 }
                                ),
                                in: 0...900,
                                step: 5
                            )
                        }
                        .padding(.vertical, 4)
                    }

                    Button("+ Προσθήκη Νέου Βήματος / Block") {
                        blocks.append(
                            TemplateBlockInput(
                                repeatCount: 1,
                                recordKind: sport.defaultRecordKind,
                                distanceM: sport.defaultRecordKind == .timedDistance ? 100 : nil,
                                strokeOrMovement: sport.availableMovements.first ?? "surface",
                                restMode: .fixedRest,
                                restOrSendoffMs: 30_000
                            )
                        )
                    }
                }

                if !versionHistory.isEmpty {
                    Section("Ιστορικό Εκδόσεων Πρωτοκόλλου (Immutable SHA-256)") {
                        ForEach(versionHistory) { ver in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Version v\(ver.versionNumber)")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.electricLime)
                                    Spacer()
                                    Text("\(ver.totalReps) reps · \(ver.totalDistanceM.map { "\($0)m" } ?? "")")
                                        .font(.system(size: 12, design: .monospaced))
                                }
                                Text("SHA-256: \(String(ver.protocolHash.prefix(24)))…")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(L4NETheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingTemplate == nil ? "Create Template" : "Edit Protocol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTemplate == nil ? "Save Protocol" : "Save (Auto-Version)") {
                        saveTemplate()
                    }
                }
            }
            .onAppear {
                if let tpl = existingTemplate {
                    name = tpl.name
                    folderTag = tpl.folderTag ?? ""
                    sport = tpl.sportCategory
                    poolLengthM = tpl.poolLengthM ?? 50
                    rounds = tpl.activeVersion.rounds
                    roundRestSeconds = Int(tpl.activeVersion.roundRestMs / 1000)
                    selectedEquipment = Set(tpl.activeVersion.equipment)
                    notes = tpl.activeVersion.notes ?? ""
                    blocks = tpl.activeVersion.blocks.map {
                        TemplateBlockInput(
                            repeatCount: $0.repeatCount,
                            recordKind: $0.recordKind,
                            distanceM: $0.distanceM,
                            strokeOrMovement: $0.strokeOrMovement,
                            restMode: $0.restMode,
                            restOrSendoffMs: $0.restOrSendoffMs,
                            targetDurationMs: $0.targetDurationMs
                        )
                    }
                    versionHistory = (try? store.client.listTemplateVersions(templateId: tpl.id)) ?? []
                }
            }
        }
    }

    private enum PresetKind {
        case monofin8x50
        case bifinsPyramid
        case compoundSendOff
        case track6x200
        case fieldLongJump
        case gymSquat5x5
    }

    private func applyPreset(_ preset: PresetKind) {
        switch preset {
        case .monofin8x50:
            name = "8×50m Surface Monofin — 30s Rest"
            sport = .finswimming
            poolLengthM = 50
            rounds = 1
            selectedEquipment = ["monofin", "snorkel"]
            blocks = [
                TemplateBlockInput(repeatCount: 8, distanceM: 50, strokeOrMovement: "surface", restMode: .fixedRest, restOrSendoffMs: 30_000)
            ]
        case .bifinsPyramid:
            name = "50-100-150-100-50m Bifins Pyramid"
            sport = .finswimming
            poolLengthM = 50
            rounds = 1
            selectedEquipment = ["bifins", "snorkel"]
            blocks = [50, 100, 150, 100, 50].map { d in
                TemplateBlockInput(repeatCount: 1, distanceM: d, strokeOrMovement: "bifins", restMode: .fixedRest, restOrSendoffMs: 30_000)
            }
        case .compoundSendOff:
            name = "4 × [2×50m @ 0:50 + 1×100m @ 1:40] Send-Off"
            sport = .swimming
            poolLengthM = 50
            rounds = 4
            roundRestSeconds = 30
            selectedEquipment = ["paddles"]
            blocks = [
                TemplateBlockInput(repeatCount: 2, distanceM: 50, strokeOrMovement: "freestyle", restMode: .sendOff, restOrSendoffMs: 50_000),
                TemplateBlockInput(repeatCount: 1, distanceM: 100, strokeOrMovement: "freestyle", restMode: .sendOff, restOrSendoffMs: 100_000)
            ]
        case .track6x200:
            name = "6×200m Track Sprint — 90s Rest"
            sport = .track
            rounds = 1
            selectedEquipment = ["spikes"]
            blocks = [
                TemplateBlockInput(repeatCount: 6, distanceM: 200, strokeOrMovement: "sprint", restMode: .fixedRest, restOrSendoffMs: 90_000)
            ]
        case .fieldLongJump:
            name = "6 Attempts Long Jump Final"
            sport = .field
            rounds = 1
            selectedEquipment = ["spikes"]
            blocks = [
                TemplateBlockInput(repeatCount: 6, recordKind: .distanceAttempt, distanceM: nil, strokeOrMovement: "long_jump", restMode: .fixedRest, restOrSendoffMs: 120_000)
            ]
        case .gymSquat5x5:
            name = "5×5 Back Squat Strength"
            sport = .gym
            rounds = 1
            selectedEquipment = ["barbell"]
            blocks = [
                TemplateBlockInput(repeatCount: 5, recordKind: .weightReps, distanceM: nil, strokeOrMovement: "back_squat", restMode: .fixedRest, restOrSendoffMs: 180_000)
            ]
        }
    }

    private func saveTemplate() {
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? "L4NE Protocol"
            : name
        let poolOpt: Int? = (sport == .swimming || sport == .finswimming) ? poolLengthM : nil
        let env: EnvironmentType = (sport == .swimming || sport == .finswimming)
            ? .pool
            : (sport == .track || sport == .field ? .track : .gym)

        let cleanFolder = folderTag.trimmingCharacters(in: .whitespaces).isEmpty ? nil : folderTag

        if let existing = existingTemplate {
            store.updateTemplateProtocol(
                UpdateTemplateProtocolInput(
                    templateId: existing.id,
                    name: finalName,
                    poolLengthM: poolOpt,
                    folderTag: cleanFolder,
                    rounds: rounds,
                    roundRestMs: Int64(roundRestSeconds) * 1000,
                    equipment: Array(selectedEquipment).sorted(),
                    targetPaceMsPer100m: existing.activeVersion.targetPaceMsPer100m,
                    notes: notes.isEmpty ? nil : notes,
                    blocks: blocks
                )
            )
        } else {
            store.createTemplate(
                CreateTemplateInput(
                    name: finalName,
                    sportCategory: sport,
                    poolLengthM: poolOpt,
                    environment: env,
                    folderTag: cleanFolder,
                    rounds: rounds,
                    roundRestMs: Int64(roundRestSeconds) * 1000,
                    equipment: Array(selectedEquipment).sorted(),
                    notes: notes.isEmpty ? nil : notes,
                    blocks: blocks
                )
            )
        }
        dismiss()
    }
}

// MARK: - 3. Post-Workout Session Logging Screen (Centisecond Numpad + Multi-Sport Field/Gym Inputs)

public struct SessionLoggingView: View {
    @ObservedObject var store: L4NEAppStore
    public let template: TemplateWithVersion
    @Environment(\.dismiss) private var dismiss

    @State private var slots: [ExpectedRepSlot] = []
    @State private var currentSlotIndex: Int = 1
    @State private var rawDigitsBySlot: [Int: String] = [:]
    @State private var parsedMsBySlot: [Int: Int64] = [:]
    @State private var strokeCountBySlot: [Int: Int] = [:]
    @State private var rpeBySlot: [Int: Int] = [:]
    @State private var weightKgBySlot: [Int: Double] = [:]
    @State private var repsCompletedBySlot: [Int: Int] = [:]
    @State private var attemptMetersBySlot: [Int: Double] = [:]
    @State private var skippedSlots: Set<Int> = []
    @State private var sessionNotes: String = ""

    public init(store: L4NEAppStore, template: TemplateWithVersion) {
        self.store = store
        self.template = template
    }

    private var activeSlot: ExpectedRepSlot? {
        slots.first(where: { $0.slotIndex == currentSlotIndex })
    }

    private var runningAvgMs: Int64? {
        let vals = Array(parsedMsBySlot.values)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Int64(vals.count)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Slot horizontal strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(slots) { slot in
                            let isCurrent = slot.slotIndex == currentSlotIndex
                            let isSkipped = skippedSlots.contains(slot.slotIndex)
                            Button {
                                currentSlotIndex = slot.slotIndex
                            } label: {
                                VStack(spacing: 3) {
                                    Text("#\(slot.slotIndex) · \(slot.distanceM.map { "\($0)m" } ?? slot.strokeOrMovement)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    Text(isSkipped ? "SKIP" : slotBadgeText(for: slot))
                                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
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

                if let activeSlot {
                    VStack(spacing: 8) {
                        HStack {
                            Text("REP #\(activeSlot.slotIndex) OF \(slots.count) · ROUND \(activeSlot.roundIndex)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.textSecondary)
                            Spacer()
                            if let avg = runningAvgMs {
                                Text("RUNNING AVG: \(L4NEDurationFormatter.formatMs(avg))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(L4NETheme.signalGreen)
                            }
                        }

                        if activeSlot.recordKind == .timedDistance {
                            let raw = rawDigitsBySlot[currentSlotIndex] ?? ""
                            let formatted = (try? store.client.parseAthleticNumpad(digits: raw).formattedDisplay) ?? "00.00"

                            Text(formatted)
                                .font(.system(size: 44, weight: .black, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(L4NETheme.electricLime)

                            HStack(spacing: 14) {
                                if activeSlot.restMode == .sendOff, let dur = parsedMsBySlot[currentSlotIndex] {
                                    let actualRest = max(0, activeSlot.restOrSendoffMs - dur)
                                    Text("ACTUAL REST: \(L4NEDurationFormatter.formatMs(actualRest))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.signalGreen)
                                } else {
                                    Text("REST: \(L4NEDurationFormatter.formatIntervalMs(activeSlot.restOrSendoffMs))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.textSecondary)
                                }

                                Stepper(
                                    "Strokes: \(strokeCountBySlot[currentSlotIndex] ?? 0)",
                                    value: Binding(
                                        get: { strokeCountBySlot[currentSlotIndex] ?? 0 },
                                        set: { strokeCountBySlot[currentSlotIndex] = $0 > 0 ? $0 : nil }
                                    ),
                                    in: 0...80
                                )
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                        } else if activeSlot.recordKind == .weightReps {
                            // Gym Weight x Reps UI
                            VStack(spacing: 8) {
                                Stepper(
                                    String(format: "Weight: %.1f kg", weightKgBySlot[currentSlotIndex] ?? 100.0),
                                    value: Binding(
                                        get: { weightKgBySlot[currentSlotIndex] ?? 100.0 },
                                        set: { weightKgBySlot[currentSlotIndex] = $0 }
                                    ),
                                    in: 2.5...500.0,
                                    step: 2.5
                                )
                                Stepper(
                                    "Reps Completed: \(repsCompletedBySlot[currentSlotIndex] ?? 5)",
                                    value: Binding(
                                        get: { repsCompletedBySlot[currentSlotIndex] ?? 5 },
                                        set: { repsCompletedBySlot[currentSlotIndex] = $0 }
                                    ),
                                    in: 1...50
                                )
                            }
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        } else {
                            // Field Attempt Distance/Height UI
                            Stepper(
                                String(format: "Attempt Result: %.2f m", attemptMetersBySlot[currentSlotIndex] ?? 7.15),
                                value: Binding(
                                    get: { attemptMetersBySlot[currentSlotIndex] ?? 7.15 },
                                    set: { attemptMetersBySlot[currentSlotIndex] = $0 }
                                ),
                                in: 0.50...100.0,
                                step: 0.05
                            )
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(L4NETheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }

                Spacer()

                // Custom Athletic Centisecond Numpad
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Button("SAME PREV") {
                            if currentSlotIndex > 1,
                               let prev = rawDigitsBySlot[currentSlotIndex - 1] {
                                applyDigits(prev)
                            }
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(L4NETheme.mutedSurface)
                        .foregroundStyle(L4NETheme.electricLime)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("-0.10s") { adjustCurrentMs(by: -100) }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(L4NETheme.mutedSurface)
                            .foregroundStyle(L4NETheme.signalGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("+0.10s") { adjustCurrentMs(by: 100) }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(L4NETheme.mutedSurface)
                            .foregroundStyle(L4NETheme.warningAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("SKIP") {
                            skippedSlots.insert(currentSlotIndex)
                            if currentSlotIndex < slots.count { currentSlotIndex += 1 }
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
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
                                        .frame(height: 50)
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
                }
            }
            .onAppear {
                slots = (try? store.client.expandTemplateSlots(templateVersionId: template.activeVersion.id)) ?? []
            }
        }
    }

    private func slotBadgeText(for slot: ExpectedRepSlot) -> String {
        switch slot.recordKind {
        case .timedDistance:
            return parsedMsBySlot[slot.slotIndex].map { L4NEDurationFormatter.formatMs($0) } ?? "--.--"
        case .weightReps:
            if let w = weightKgBySlot[slot.slotIndex], let r = repsCompletedBySlot[slot.slotIndex] {
                return "\(Int(w))kg×\(r)"
            }
            return "--kg"
        case .distanceAttempt:
            if let m = attemptMetersBySlot[slot.slotIndex] {
                return String(format: "%.2fm", m)
            }
            return "--m"
        }
    }

    private func adjustCurrentMs(by deltaMs: Int64) {
        let base = parsedMsBySlot[currentSlotIndex] ?? 20_000
        let updated = max(100, base + deltaMs)
        parsedMsBySlot[currentSlotIndex] = updated
        let totalCs = (updated + 5) / 10
        let cs = totalCs % 100
        let totalSec = totalCs / 100
        let mins = totalSec / 60
        let secs = totalSec % 60
        if mins > 0 {
            rawDigitsBySlot[currentSlotIndex] = String(format: "%lld%02lld%02lld", mins, secs, cs)
        } else {
            rawDigitsBySlot[currentSlotIndex] = String(format: "%lld%02lld", secs, cs)
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
            if let slot = activeSlot {
                if slot.recordKind == .weightReps && weightKgBySlot[currentSlotIndex] == nil {
                    weightKgBySlot[currentSlotIndex] = 100.0
                    repsCompletedBySlot[currentSlotIndex] = 5
                } else if slot.recordKind == .distanceAttempt && attemptMetersBySlot[currentSlotIndex] == nil {
                    attemptMetersBySlot[currentSlotIndex] = 7.15
                }
            }
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
        skippedSlots.remove(currentSlotIndex)
        rawDigitsBySlot[currentSlotIndex] = digits
        if let parsed = try? store.client.parseAthleticNumpad(digits: digits) {
            parsedMsBySlot[currentSlotIndex] = parsed.durationMs
        } else {
            parsedMsBySlot[currentSlotIndex] = nil
        }
    }

    private func saveLoggedSession() {
        let repInputs: [RepInput] = slots.compactMap { slot in
            let idx = slot.slotIndex
            if skippedSlots.contains(idx) {
                return RepInput(slotIndex: idx, durationMs: nil, isSkipped: true)
            }
            switch slot.recordKind {
            case .timedDistance:
                guard let ms = parsedMsBySlot[idx] else { return nil }
                return RepInput(
                    slotIndex: idx,
                    durationMs: ms,
                    strokeCount: strokeCountBySlot[idx],
                    rpe: rpeBySlot[idx]
                )
            case .weightReps:
                guard let w = weightKgBySlot[idx], let r = repsCompletedBySlot[idx] else { return nil }
                return RepInput(
                    slotIndex: idx,
                    durationMs: nil,
                    rpe: rpeBySlot[idx],
                    weightKg: w,
                    repsCompleted: r
                )
            case .distanceAttempt:
                guard let m = attemptMetersBySlot[idx] else { return nil }
                return RepInput(
                    slotIndex: idx,
                    durationMs: nil,
                    attemptResultM: m
                )
            }
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

// MARK: - 4. Template Analytics Screen (v1.1 with Native Swift Charts, Custom Baseline Picker & HK Export)

public struct TemplateAnalyticsView: View {
    @ObservedObject var store: L4NEAppStore
    public let templateId: String

    @State private var template: TemplateWithVersion?
    @State private var report: TemplateAnalyticsReport?
    @State private var sessions: [SessionWithReps] = []
    @State private var selectedCurrentSessionId: String = ""
    @State private var selectedBaselineSessionId: String = ""
    @State private var customComparison: SessionComparison?

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
                        if let pbPace = report.personalBestPaceMsPer100m {
                            L4NEMetricTile(
                                title: "Personal Best Pace",
                                value: L4NEDurationFormatter.formatPacePer100m(pbPace),
                                subtitle: "Active Protocol v\(report.activeVersionNumber)",
                                accentColor: L4NETheme.electricLime
                            )
                        } else if let pbTonnage = report.personalBestTonnageKg {
                            L4NEMetricTile(
                                title: "Personal Best Tonnage",
                                value: String(format: "%.0f kg", pbTonnage),
                                subtitle: "Best 1RM: \(String(format: "%.1f kg", report.personalBest1RmKg ?? 0))",
                                accentColor: L4NETheme.electricLime
                            )
                        } else if let pbAtt = report.personalBestAttemptM {
                            L4NEMetricTile(
                                title: "Personal Best Attempt",
                                value: String(format: "%.2f m", pbAtt),
                                subtitle: "Active Protocol v\(report.activeVersionNumber)",
                                accentColor: L4NETheme.electricLime
                            )
                        }

                        L4NEMetricTile(
                            title: "Best Single Rep",
                            value: report.personalBestRepDurationMs.map { L4NEDurationFormatter.formatMs($0) } ?? "Multi-Block",
                            subtitle: "Total Sessions: \(report.totalSessions)",
                            accentColor: L4NETheme.signalGreen
                        )
                    }

                    // Native Swift Charts: Intra-Session Rep-by-Rep Pace & Fatigue Curve
                    #if canImport(Charts)
                    if let latestSession = sessions.first, !latestSession.reps.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LATEST SESSION REP-BY-REP PERFORMANCE CURVE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.textSecondary)

                            Chart {
                                ForEach(latestSession.reps.filter { !$0.isSkipped }) { rep in
                                    let yVal = Double(rep.paceMsPer100m ?? rep.durationMs ?? 0) / 1000.0
                                    BarMark(
                                        x: .value("Rep", "#\(rep.slotIndex)"),
                                        y: .value("Seconds", yVal)
                                    )
                                    .foregroundStyle(L4NETheme.electricLime.gradient)
                                }
                            }
                            .frame(height: 165)
                        }
                        .padding(14)
                        .background(L4NETheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    #endif

                    // Custom Session-vs-Session Comparison Selector
                    if sessions.count >= 2 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DETERMINISTIC SESSION COMPARISON")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.textSecondary)

                            HStack {
                                Picker("Current", selection: $selectedCurrentSessionId) {
                                    ForEach(sessions) { s in
                                        Text("\(L4NEDurationFormatter.formatEpochDate(s.performedAtMs)) (v\(s.templateVersionNumber))")
                                            .tag(s.id)
                                    }
                                }
                                Picker("Baseline", selection: $selectedBaselineSessionId) {
                                    ForEach(sessions) { s in
                                        Text("\(L4NEDurationFormatter.formatEpochDate(s.performedAtMs)) (v\(s.templateVersionNumber))")
                                            .tag(s.id)
                                    }
                                }
                            }
                            .onChange(of: selectedCurrentSessionId) { _, _ in recomputeComparison() }
                            .onChange(of: selectedBaselineSessionId) { _, _ in recomputeComparison() }

                            if let cmp = customComparison ?? report.latestVsPrevious {
                                HStack {
                                    Text("DELTA SUMMARY")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.textSecondary)
                                    Spacer()
                                    Text(String(format: "%+.2f%% IMPROVEMENT", cmp.totalImprovementPct))
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
                                        .foregroundStyle(cmp.totalImprovementPct >= 0 ? L4NETheme.signalGreen : L4NETheme.regressionRed)
                                }

                                if let warning = cmp.protocolWarning {
                                    Text(warning)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(L4NETheme.warningAmber)
                                }

                                ForEach(cmp.slotDeltas) { delta in
                                    HStack {
                                        Text("Slot #\(delta.slotIndex) (\(delta.distanceM ?? 0)m)")
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
                                                .frame(width: 72, alignment: .trailing)
                                        }
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                        }
                        .padding(14)
                        .background(L4NETheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Historical Sessions Management (Export to Apple HealthKit v1.1 + Delete)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SESSION HISTORY & APPLE HEALTHKIT EXPORT (v1.1)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.textSecondary)

                        ForEach(sessions) { s in
                            VStack(alignment: .leading, spacing: 8) {
                                SessionSummaryCard(session: s)
                                HStack(spacing: 12) {
                                    Button {
                                        Task {
                                            await store.exportSessionToAppleHealth(
                                                session: s,
                                                sport: template?.sportCategory ?? .swimming
                                            )
                                            reloadAnalytics()
                                        }
                                    } label: {
                                        Label(
                                            s.exportedExternalUuid == nil ? "Export to Apple Health" : "Exported to HealthKit",
                                            systemImage: "heart.text.square.fill"
                                        )
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(s.exportedExternalUuid == nil ? L4NETheme.electricLime : L4NETheme.signalGreen)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(s.exportedExternalUuid != nil)

                                    Spacer()

                                    Button(role: .destructive) {
                                        store.deleteSession(sessionId: s.id)
                                        reloadAnalytics()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(L4NETheme.regressionRed)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 6)
                            }
                        }
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
            reloadAnalytics()
        }
    }

    private func reloadAnalytics() {
        template = try? store.client.getTemplate(id: templateId)
        report = try? store.client.getTemplateAnalytics(templateId: templateId)
        sessions = (try? store.client.listSessions(templateId: templateId)) ?? []
        if sessions.count >= 2 {
            selectedCurrentSessionId = sessions[0].id
            selectedBaselineSessionId = sessions[1].id
            recomputeComparison()
        }
    }

    private func recomputeComparison() {
        guard !selectedCurrentSessionId.isEmpty,
              !selectedBaselineSessionId.isEmpty,
              selectedCurrentSessionId != selectedBaselineSessionId else {
            customComparison = nil
            return
        }
        customComparison = try? store.client.compareSessions(
            currentSessionId: selectedCurrentSessionId,
            baselineSessionId: selectedBaselineSessionId
        )
    }
}

// MARK: - 5. Daily Training Timeline & Recovery Context Editor Screen

public struct DailyTimelineView: View {
    @ObservedObject var store: L4NEAppStore
    @State private var showHealthEditor = false

    public init(store: L4NEAppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Date Switcher Strip
                    HStack(spacing: 8) {
                        ForEach(["2026-11-22", "2026-11-15"], id: \.self) { dateIso in
                            Button {
                                store.selectedTimelineDateIso = dateIso
                                store.refreshAll()
                            } label: {
                                Text(dateIso)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(store.selectedTimelineDateIso == dateIso ? L4NETheme.electricLime : L4NETheme.cardSurface)
                                    .foregroundStyle(store.selectedTimelineDateIso == dateIso ? Color.black : L4NETheme.textPrimary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Button {
                            showHealthEditor = true
                        } label: {
                            Label("Log Recovery", systemImage: "bed.double.fill")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(L4NETheme.mutedSurface)
                                .foregroundStyle(L4NETheme.electricLime)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

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
                                Text("RECOVERY CONTEXT (\(health.dateIso))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(L4NETheme.electricLime)
                                Text("Sleep: \((health.sleepDurationMinutes ?? 0) / 60)h \((health.sleepDurationMinutes ?? 0) % 60)m · HRV: \(String(format: "%.1f", health.hrvSdnnMs ?? 0)) ms · RHR: \(String(format: "%.0f", health.restingHrBpm ?? 0)) bpm · VO₂ Max: \(String(format: "%.1f", health.vo2MaxMlKgMin ?? 0))")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
                            VStack(alignment: .leading, spacing: 6) {
                                SessionSummaryCard(session: s)
                                if let firstWorkout = timeline.workouts.first {
                                    HStack {
                                        Text(s.workoutId == firstWorkout.id ? "Linked to \(firstWorkout.externalSourceName ?? "Watch Workout")" : "Standalone Manual Session")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(L4NETheme.textSecondary)
                                        Spacer()
                                        Button(s.workoutId == firstWorkout.id ? "Unlink Workout" : "Link to Watch Workout") {
                                            store.linkSessionToWorkout(
                                                sessionId: s.id,
                                                workoutId: s.workoutId == firstWorkout.id ? nil : firstWorkout.id
                                            )
                                        }
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(L4NETheme.electricLime)
                                    }
                                    .padding(.horizontal, 6)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(L4NETheme.background.ignoresSafeArea())
            .navigationTitle("Daily Timeline")
            .sheet(isPresented: $showHealthEditor) {
                HealthSnapshotEditorSheet(store: store, dateIso: store.selectedTimelineDateIso)
            }
        }
    }
}

struct HealthSnapshotEditorSheet: View {
    @ObservedObject var store: L4NEAppStore
    let dateIso: String
    @Environment(\.dismiss) private var dismiss

    @State private var sleepMinutes: Int = 480
    @State private var hrvMs: Double = 72.0
    @State private var rhrBpm: Double = 49.0
    @State private var vo2Max: Double = 62.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Recovery Metrics (\(dateIso))") {
                    Stepper("Ύπνος: \(sleepMinutes / 60)h \(sleepMinutes % 60)m", value: $sleepMinutes, in: 120...720, step: 15)
                    Stepper(String(format: "HRV (SDNN): %.1f ms", hrvMs), value: $hrvMs, in: 15.0...200.0, step: 1.0)
                    Stepper(String(format: "Resting HR: %.0f bpm", rhrBpm), value: $rhrBpm, in: 32.0...100.0, step: 1.0)
                    Stepper(String(format: "VO₂ Max: %.1f ml/kg/min", vo2Max), value: $vo2Max, in: 25.0...90.0, step: 0.5)
                }
            }
            .navigationTitle("Log Health Snapshot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.saveHealthSnapshot(
                            DailyHealthSnapshot(
                                dateIso: dateIso,
                                sleepDurationMinutes: sleepMinutes,
                                hrvSdnnMs: hrvMs,
                                restingHrBpm: rhrBpm,
                                vo2MaxMlKgMin: vo2Max,
                                sourceSummary: "Manual / Apple Health Context",
                                capturedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 6. Apple HealthKit Workout Import & Deterministic Matching Screen (v1.1 Read + Write)

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
                        Text("APPLE HEALTHKIT INTEGRATION (READ & WRITE v1.1)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(L4NETheme.electricLime)
                        Text("Status: \(store.healthKitStatus.rawValue)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(L4NETheme.textPrimary)

                        HStack(spacing: 10) {
                            Button("Authorize Read & Write") {
                                Task {
                                    store.healthKitStatus = await store.healthKitAdapter.requestReadAndWriteAuthorization()
                                }
                            }
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(L4NETheme.electricLime)
                            .foregroundStyle(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button("Import Watch Workout") {
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
                                    if !(workout.lapDurationsMs ?? []).isEmpty {
                                        Button("Auto-Log Laps") {
                                            if let prefilled = try? store.client.prefillRepsFromWorkoutLaps(
                                                workoutId: workout.id,
                                                templateVersionId: cand.templateVersionId
                                            ), !prefilled.isEmpty {
                                                store.logSession(
                                                    LogSessionInput(
                                                        templateId: cand.templateId,
                                                        templateVersionId: cand.templateVersionId,
                                                        workoutId: workout.id,
                                                        performedAtMs: workout.startedAtMs,
                                                        poolLengthM: workout.poolLengthM,
                                                        notes: "Auto-logged from Apple Watch lap events (v1.2)",
                                                        reps: prefilled
                                                    )
                                                )
                                            }
                                        }
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(L4NETheme.electricLime)
                                        .foregroundStyle(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
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

// MARK: - 7. Settings, Local-First Backup/Restore & Diagnostics Screen (v1.1)

public struct SettingsDataView: View {
    @ObservedObject var store: L4NEAppStore
    @State private var restoreInputText: String = ""
    @State private var showRestoreSheet = false

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

                    if let diag = store.diagnostics {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            L4NEMetricTile(title: "Templates", value: "\(diag.templatesCount)", subtitle: "\(diag.templateVersionsCount) versions")
                            L4NEMetricTile(title: "Sessions", value: "\(diag.sessionsCount)", subtitle: "\(diag.repRecordsCount) reps")
                            L4NEMetricTile(title: "Workouts", value: "\(diag.workoutsCount)", subtitle: "Schema v\(diag.schemaVersion)")
                        }
                    }

                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Button("Export JSON Backup") {
                                store.exportJSONBackup()
                            }
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(L4NETheme.electricLime)
                            .foregroundStyle(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button("Restore JSON Backup") {
                                restoreInputText = store.lastExportPreview ?? ""
                                showRestoreSheet = true
                            }
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(L4NETheme.mutedSurface)
                            .foregroundStyle(L4NETheme.electricLime)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button("Export All Sessions & Reps (CSV)") {
                            store.exportCSV()
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(L4NETheme.cardSurface)
                        .foregroundStyle(L4NETheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let preview = store.lastExportPreview {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PORTABLE DATA OUTPUT PREVIEW")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(L4NETheme.electricLime)
                            Text(String(preview.prefix(1400)))
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
            .sheet(isPresented: $showRestoreSheet) {
                NavigationStack {
                    VStack(spacing: 12) {
                        Text("Paste a portable L4NE JSON Backup payload to restore idempotently into SQLite:")
                            .font(.system(size: 12))
                            .foregroundStyle(L4NETheme.textSecondary)
                        TextEditor(text: $restoreInputText)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(8)
                            .background(L4NETheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(16)
                    .navigationTitle("Restore JSON Backup")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showRestoreSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Restore Now") {
                                store.restoreJSONBackup(restoreInputText)
                                showRestoreSheet = false
                            }
                            .disabled(restoreInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }
}
