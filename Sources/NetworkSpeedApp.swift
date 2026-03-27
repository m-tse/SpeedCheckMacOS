import SwiftUI

@main
struct NetworkSpeedApp: App {
    @StateObject private var speedTest = SpeedTestManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(speedTest)
        } label: {
            Text(speedTest.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
