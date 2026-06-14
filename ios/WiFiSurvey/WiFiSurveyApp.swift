import SwiftUI

@main
struct WiFiSurveyApp: App {
    @StateObject private var store = SurveyStore()
    @StateObject private var bluetooth = BLEProvisioningService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(bluetooth)
                .task {
                    bluetooth.onIPAddress = { ip in
                        store.useDiscoveredHost(ip)
                    }
                    bluetooth.onStatus = { status in
                        store.register(status: status)
                    }
                }
        }
    }
}
