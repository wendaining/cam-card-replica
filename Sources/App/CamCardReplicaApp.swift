import SwiftUI

@main
struct CamCardReplicaApp: App {
    @State private var services = AppServices.make()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .tint(.accentColor)
        }
    }
}
