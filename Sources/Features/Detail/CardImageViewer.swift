import SwiftUI

/// Full-screen viewer for a saved card, with a toggle between the original
/// capture and the perspective-corrected image (spec 十: "查看原始名片").
struct CardImageViewer: View {
    let card: BusinessCard
    let library: CardLibraryModel

    @Environment(\.dismiss) private var dismiss
    @State private var showsOriginal = false

    private var hasOriginal: Bool {
        guard let id = card.originalImageID else { return false }
        return library.imageData(for: card, original: true) != nil && id != card.processedImageID
    }

    private var currentImage: CGImage? {
        guard let data = library.imageData(for: card, original: showsOriginal && hasOriginal) else { return nil }
        return ImageCoding.cgImage(from: data)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = currentImage {
                    ScrollView([.horizontal, .vertical]) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("card-image")
                    }
                } else {
                    EmptyStateView(
                        title: "没有图片",
                        message: "这张名片保存时没有留下图片。",
                        systemImage: "photo"
                    )
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if hasOriginal {
                        Picker("图片", selection: $showsOriginal) {
                            Text("校正图").tag(false)
                            Text("原图").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                        .accessibilityIdentifier("image-source-picker")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .accessibilityIdentifier("image-viewer-done")
                }
            }
        }
    }
}
