import SwiftUI

@main
struct CTRLApp: App {

    @StateObject private var appState = AppState.shared
    @StateObject private var nfcManager = NFCManager()
    @StateObject private var blockingManager = BlockingManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(nfcManager)
                .environmentObject(blockingManager)
                .preferredColorScheme(.dark)
        }
    }
}
