import SwiftUI
import SwiftData

@main
struct PersonalFinanceLedgerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(for: Transaction.self)
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 700)
    }
}
