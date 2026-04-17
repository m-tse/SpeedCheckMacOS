import SwiftUI
import AppKit

@main
struct SpeedCheckApp: App {
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
            .foregroundColor: NSColor.black,
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let size = attrStr.size()
        let image = NSImage(size: size)
        image.lockFocus()
        attrStr.draw(at: NSPoint(x: 0, y: -font.descender / 2 - 0.5))
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
