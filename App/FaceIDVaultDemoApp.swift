import SwiftUI

@main
struct FaceIDVaultDemoApp: App {
    init() {
        #if EMBEDDED_BYPASS
        if CommandLine.arguments.contains("-bypass") {
            InstallFaceIDBypass()
        }
        #endif
        if CommandLine.arguments.contains("-selftest") {
            SelfTest.run()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
