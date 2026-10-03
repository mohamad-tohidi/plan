import SwiftUI
import AppKit

@main
struct WhiteboardScrumPlannerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: Store

    init() {
        _store = State(initialValue: MainActor.assumeIsolated { Store() })
    }

    var body: some Scene {
        WindowGroup("Whiteboard Scrum Planner") {
            BoardView()
                .environment(store)
                .frame(minWidth: 1100, minHeight: 560)
        }
        .defaultSize(width: 1080, height: 760)
        .commands {
            BoardCommands()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // We're a plain executable (no bundle), so activate explicitly.
        NSApp.setActivationPolicy(.regular)

        // Global vim-like key handling (single keys in normal mode).
        VimInput.shared.install()

        // Hidden dev tool: WBP_RENDER=/path.png renders the board offscreen
        // (for headless visual verification) and quits.
        if let path = ProcessInfo.processInfo.environment["WBP_RENDER"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                MainActor.assumeIsolated { self.renderPreview(to: path) }
            }
            return
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func renderPreview(to path: String) {
        let store = Store()

        // Render the fixed-width sheet directly: ScrollView renders nothing in
        // offscreen ImageRenderer contexts, and .dropDestination paints an
        // opaque yellow drop-target backdrop offscreen (a renderer-only
        // artifact — it is invisible in the live app).
        let view = BoardSheet(actions: BoardActions())
            .environment(store)
            .frame(width: 1280, height: 900, alignment: .top)
            .background(Style.hay)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("WBP_RENDER written: \(path)")
        } else {
            print("WBP_RENDER failed to render")
        }
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}