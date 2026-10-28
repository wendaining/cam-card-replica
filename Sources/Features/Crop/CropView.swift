import SwiftUI

/// Crop / perspective step (spec 7.3, T06).
///
/// The detected quad is pre-filled; every corner can be dragged, which is the
/// documented fallback when detection fails on dark or cluttered backgrounds.
struct CropView: View {
    @Bindable var model: ScanFlowModel
    @State private var quad: Quad = .fullFrame
    @State private var didLoad = false

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let image = model.capturedImage
                let imageSize = image.map { CGSize(width: $0.width, height: $0.height) } ?? CGSize(width: 4, height: 3)
                let fitted = fittedRect(for: imageSize, in: proxy.size)
                ZStack(alignment: .topLeading) {
                    Color.black
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .frame(width: fitted.width, height: fitted.height)
                            .position(x: fitted.midX, y: fitted.midY)
                    }
                    QuadOverlay(quad: quad, rect: fitted)
                    ForEach(Array(Corner.allCases.enumerated()), id: \.offset) { _, corner in
                        handle(for: corner, in: fitted)
                    }
                }
                .contentShape(Rectangle())
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(A11y.cropView)

            if let message = model.errorMessage {
                Text(message).foregroundStyle(.orange).font(.footnote)
                    .accessibilityIdentifier("scan-error")
            }
            hint
            buttons
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("调整名片区域")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didLoad else { return }
            quad = model.quad.isPlausible ? model.quad : .fullFrame
            didLoad = true
        }
        .onChange(of: quad) { _, newValue in
            model.quad = newValue.clamped()
        }
    }

    private var hint: some View {
        Text("拖动四个角对齐名片边缘，或直接使用整张图片。")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }

    private var buttons: some View {
        HStack(spacing: 16) {
            Button("重新拍摄") { model.retake() }
                .buttonStyle(.bordered)
                .tint(.white)
                .accessibilityIdentifier(A11y.cropRetake)
            Button("使用整张图片") { quad = .fullFrame }
                .buttonStyle(.bordered)
                .tint(.white)
            Button {
                Task { await model.confirmCrop() }
            } label: {
                Text("下一步").bold()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(A11y.cropConfirm)
        }
        .padding(.bottom, 12)
    }

    private func handle(for corner: Corner, in rect: CGRect) -> some View {
        let point = corner.point(in: quad)
        return Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .frame(width: 26, height: 26)
            .position(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = ((value.location.x - rect.minX) / rect.width).clamped01
                        let y = ((value.location.y - rect.minY) / rect.height).clamped01
                        quad = quad.moving(corner, to: CGPoint(x: x, y: y))
                    }
            )
    }

    private func fittedRect(for imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

// MARK: - Geometry helpers

enum Corner: CaseIterable {
    case topLeft, topRight, bottomRight, bottomLeft

    func point(in quad: Quad) -> CGPoint {
        switch self {
        case .topLeft: quad.topLeft
        case .topRight: quad.topRight
        case .bottomRight: quad.bottomRight
        case .bottomLeft: quad.bottomLeft
        }
    }
}

extension Quad {
    func moving(_ corner: Corner, to point: CGPoint) -> Quad {
        var copy = self
        switch corner {
        case .topLeft: copy.topLeft = point
        case .topRight: copy.topRight = point
        case .bottomRight: copy.bottomRight = point
        case .bottomLeft: copy.bottomLeft = point
        }
        return copy
    }
}

extension CGFloat {
    var clamped01: CGFloat {
        Swift.min(Swift.max(self, 0), 1)
    }
}

/// Dims everything outside the quad and strokes its outline.
private struct QuadOverlay: View {
    let quad: Quad
    let rect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(rect)
                addQuad(to: &path)
            }
            .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

            Path { path in
                addQuad(to: &path)
            }
            .stroke(Color.accentColor, lineWidth: 2)
        }
        .allowsHitTesting(false)
    }

    private func addQuad(to path: inout Path) {
        let points = quad.points.map { point in
            CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
        }
        guard let first = points.first else { return }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
    }
}
