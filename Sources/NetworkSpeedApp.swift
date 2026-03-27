import SwiftUI
import AppKit

@main
struct NetworkSpeedApp: App {
    @StateObject private var speedTest = SpeedTestManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(speedTest)
        } label: {
            Image(nsImage: makeMenuBarImage(speedTest.menuBarTitle))
        }
        .menuBarExtraStyle(.window)
    }

    private func makeMenuBarImage(_ text: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.headerTextColor,
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let size = attrStr.size()
        let image = NSImage(size: size)
        image.lockFocus()
        attrStr.draw(at: .zero)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
