import SwiftUI

@main
struct BlinkApp: App {
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkHandler)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    DeepLinkHandler.shared.handle(url)
                }
        }
    }
}
