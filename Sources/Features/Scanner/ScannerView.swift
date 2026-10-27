import PhotosUI
import SwiftUI

/// Camera / import step (spec 7.2, T02–T05).
struct ScannerView: View {
    @Environment(AppServices.self) private var services
    @Bindable var model: ScanFlowModel

    @State private var controller = CameraController()
    @State private var pickerItem: PhotosPickerItem?
    @State private var permission: CameraPermissionStatus = .notDetermined
    @State private var isCapturing = false

    private var usesFixtures: Bool {
        services.fixtures != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            preview
            controls
        }
        .background(Color.black)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.scannerView)
        .task { await refreshPermission() }
        .onDisappear { controller.stop() }
        .onChange(of: pickerItem) { _, newValue in
            Task { await loadPickedImage(newValue) }
        }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            if usesFixtures || !permission.canUseCamera {
                Color.black
                VStack(spacing: 14) {
                    Image(systemName: permission.canUseCamera ? "photo.on.rectangle.angled" : "video.slash")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(permission.canUseCamera
                        ? "模拟器没有摄像头\n可导入相册或使用测试名片"
                        : "需要相机权限才能拍摄名片")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityIdentifier(A11y.cameraDeniedMessage)
                    if !permission.canUseCamera {
                        Button("请求相机权限") {
                            Task { await requestPermission() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                CameraPreview(session: controller.session)
                    .ignoresSafeArea(edges: .top)
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .aspectRatio(1.585, contentMode: .fit)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 18) {
            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            HStack {
                galleryButton
                Spacer()
                shutterButton
                Spacer()
                fixtureButton
            }
            .padding(.horizontal, 32)
            Text("将名片放在取景框内，尽量保持平整")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.vertical, 20)
        .background(Color.black)
    }

    private var shutterButton: some View {
        Button {
            Task { await capture() }
        } label: {
            ZStack {
                Circle().strokeBorder(Color.white, lineWidth: 4).frame(width: 74, height: 74)
                Circle().fill(Color.white).frame(width: 60, height: 60)
                if isCapturing {
                    ProgressView().tint(.black)
                }
            }
        }
        .disabled(isCapturing || (!permission.canUseCamera && !usesFixtures))
        .opacity(permission.canUseCamera || usesFixtures ? 1 : 0.4)
        .accessibilityIdentifier(A11y.shutterButton)
        .accessibilityLabel("拍摄")
    }

    private var galleryButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Image(systemName: "photo.on.rectangle")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
        }
        .accessibilityIdentifier(A11y.importButton)
        .accessibilityLabel("从相册导入")
    }

    @ViewBuilder
    private var fixtureButton: some View {
        if usesFixtures {
            Button {
                model.captureFixture()
            } label: {
                Image(systemName: "testtube.2")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
            }
            .accessibilityIdentifier("fixture-capture")
            .accessibilityLabel("使用测试名片")
        } else {
            Color.clear.frame(width: 48, height: 48)
        }
    }

    // MARK: - Actions

    private func capture() async {
        if usesFixtures {
            model.captureFixture()
            return
        }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let data = try await controller.capturePhoto()
            guard let image = ImageCoding.cgImage(from: data) else {
                model.report(error: "无法读取照片。")
                return
            }
            model.handle(image: image, orientation: ImageCoding.orientation(of: data))
        } catch {
            model.report(error: error.localizedDescription)
        }
    }

    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = ImageCoding.cgImage(from: data) else {
                model.report(error: "无法读取所选图片。")
                return
            }
            model.handle(image: image, orientation: ImageCoding.orientation(of: data))
        } catch {
            model.report(error: error.localizedDescription)
        }
    }

    private func refreshPermission() async {
        permission = services.permission.currentStatus()
        if permission == .notDetermined {
            permission = await services.permission.requestAccess()
        }
        if permission.canUseCamera {
            controller.start()
        }
    }

    private func requestPermission() async {
        permission = await services.permission.requestAccess()
        if permission.canUseCamera {
            controller.start()
        }
    }
}
