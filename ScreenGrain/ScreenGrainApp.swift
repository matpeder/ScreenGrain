import SwiftUI

@main
struct ScreenGrainApp: App {
    var body: some Scene {
        MenuBarExtra("ScreenGrain", systemImage: "circle.dotted") {
            VStack(alignment: .leading, spacing: 12) {
                Text("ScreenGrain")
                    .font(.headline)
                Text("Static texture for your displays")
                    .foregroundStyle(.secondary)
                Divider()
                Button("Quit ScreenGrain") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .frame(width: 280)
        }
        .menuBarExtraStyle(.window)
    }
}

