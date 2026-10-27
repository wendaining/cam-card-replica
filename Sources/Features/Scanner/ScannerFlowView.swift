import SwiftUI

/// Container for the whole scan journey. Each stage is a screen, which keeps the
/// "返回/取消" semantics unambiguous (T20).
struct ScannerFlowView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var model: ScanFlowModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    switch model.stage {
                    case .capture:
                        ScannerView(model: model)
                    case .preview:
                        PreviewView(model: model)
                    case .crop:
                        CropView(model: model)
                    case .processing:
                        ProcessingView()
                    case .review:
                        ReviewView(model: model, onFinish: { dismiss() })
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        if model?.stage == .review {
                            model?.cancelReview()
                        } else {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("scan-cancel")
                }
            }
        }
        .task {
            if model == nil {
                model = ScanFlowModel(services: services)
            }
        }
    }
}
