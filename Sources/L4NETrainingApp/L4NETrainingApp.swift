import SwiftUI
#if canImport(L4NETrainingUI)
import L4NETrainingUI
#endif

/// Official iOS & macOS Application Entry Point for L4NE Training (v1.1).
@main
public struct L4NETrainingApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            L4NERootView()
        }
    }
}
