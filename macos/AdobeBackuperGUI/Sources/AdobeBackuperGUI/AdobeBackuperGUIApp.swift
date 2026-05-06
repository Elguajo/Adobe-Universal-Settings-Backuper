import SwiftUI

@main
struct AdobeBackuperGUIApp: App {
    var body: some Scene {
        WindowGroup("Adobe Backuper") {
            ContentView(engine: BackupEngine())
                .frame(minWidth: 920, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
    }
}
