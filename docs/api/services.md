# 服务协议（内部 API）

所有外部不确定性（相机、OCR、检测、导出）都藏在协议后，便于注入测试替身。
协议均为 `Sendable`，实现不做全局状态。

## TextRecognizing

```swift
protocol TextRecognizing: Sendable {
    func recognize(image: CGImage, orientation: CGImagePropertyOrientation) throws -> OCRResult
}
```

- 输入：`CGImage` + EXIF 方向。
- 输出：`OCRResult { lines: [OCRTextLine], rawText, imageSize, duration, languages }`。
- 坐标约定：**归一化 0...1，原点左上**（Vision 原始为左下，已在适配层翻转）。
- 失败：抛 `VNError`；调用方降级为"空结果 + 可重拍"。

## CardDetecting

```swift
protocol CardDetecting: Sendable {
    func detectCard(in image: CGImage, orientation: CGImagePropertyOrientation) throws -> Quad?
}
```

- 返回 `nil` 表示没有可信矩形，调用方用 `Quad.fullFrame`。
- 内部按 `confidenceLevels [0.75, 0.55, 0.35]` 逐级放宽。

## ImageCorrecting

```swift
protocol ImageCorrecting: Sendable {
    func correct(_ image: CGImage, quad: Quad) throws -> CGImage
}
```

- 四角须为归一化坐标；越界抛 `ImageCorrectionError.invalidQuad`。

## FieldParsing

```swift
protocol FieldParsing: Sendable {
    func parse(_ result: OCRResult) -> ParsedCard
}
```

- 纯函数、无 IO、无随机，可对同一输入断言输出。
- 每个值携带 `confidence` 与 `evidence`；低于阈值置 `nil`，**不得补全**。

## ContactExporting

```swift
protocol ContactExporting: Sendable {
    func vCard(for card: BusinessCard) throws -> Data
    func saveToContacts(_ card: BusinessCard) async throws
}
```

- `saveToContacts` 需 `NSContactsUsageDescription` 与用户授权；拒绝抛 `accessDenied`。

## CardStore

```swift
protocol CardStore: AnyObject {
    func load() throws -> CardLibrary
    func save(_ library: CardLibrary) throws
    func writeImage(_ data: Data, id: String) throws
    func readImage(id: String) -> Data?
    func deleteImage(id: String)
}
```

- 文件实现写临时文件后 `replaceItemAt`，避免半个 JSON。
- 内存实现供 UI 测试与预览使用。

## CameraPermissionProviding

```swift
protocol CameraPermissionProviding: Sendable {
    func currentStatus() -> CameraPermissionStatus
    func requestAccess() async -> CameraPermissionStatus
}
```

- 模拟器无法弹真实相机权限：T03 用 `StubCameraPermission` 注入 `denied` 验证 UI 分支，
  真机再手工验一次真实弹窗。

## 依赖注入

`AppServices.make(arguments:)` 是唯一装配点：
`-ui-testing` / `-seed-data` / `-fixture-camera` / `-camera-permission denied`
决定用真实现还是替身。生产路径不受测试开关影响。
