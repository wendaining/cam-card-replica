import SwiftUI

/// Shown while OCR + parsing run. Kept on screen deliberately: silent latency is
/// one of the UX problems the assignment asks students to notice.
struct ProcessingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("正在识别名片…")
                .font(.headline)
            Text("文字识别与字段解析通常需要 1–3 秒")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.screenBackground)
        .accessibilityIdentifier(A11y.processingIndicator)
    }
}
