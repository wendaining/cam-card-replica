import SwiftUI

/// "Is this shot usable?" — the explicit step between shooting and cropping
/// (spec 7.2 "拍摄结果预览").
///
/// It exists because the crop screen asks a different question ("where are the
/// corners"); making the user answer "did the photo even come out" on the same
/// screen hides a failed shot behind a drag gesture.
struct PreviewView: View {
    @Bindable var model: ScanFlowModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let image = model.capturedImage {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 8)
                }
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 14) {
                Text("照片可以用吗？")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("模糊、反光或没拍到整张名片，就重拍一次。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button {
                        model.retake()
                    } label: {
                        Label("重拍", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .accessibilityIdentifier(A11y.previewRetake)

                    Button {
                        Task { await model.confirmPreview() }
                    } label: {
                        Label("使用这张", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(A11y.previewUse)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 18)
            .background(Color.black)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.previewView)
        .navigationTitle("确认照片")
        .navigationBarTitleDisplayMode(.inline)
    }
}
