import SwiftUI

struct RootView: View {
    @Environment(AppServices.self) private var services
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            CardListView(onScan: { isScanning = true })
                .navigationDestination(for: BusinessCard.ID.self) { id in
                    CardDetailView(cardID: id)
                }
        }
        .fullScreenCover(isPresented: $isScanning) {
            ScannerFlowView()
        }
    }
}

#Preview {
    RootView()
        .environment(AppServices.make(arguments: ["-ui-testing"]))
}
