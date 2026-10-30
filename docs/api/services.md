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
- 失败：抛 VNError；调用方回裁剪页，明确显示识别失败，可重试/重拍。识别结果为空则进入空确认表单，可手填。
- 检测、校正、OCR 由 ScanFlowModel 放在后台任务执行；取消使任务 token 失效，迟到结果不更新 UI。

## ScanFlowModel 相册入口

`importImage(using:)` 接收异步 Data 加载闭包；PhotosPicker 只负责提供加载器。新选择先使旧任务 token 失效，加载返回后验证 token 和取消状态，再解码并进入裁剪。旧成功/失败结果均忽略；当前加载的空数据、损坏图片或异常显示错误。拍摄、重拍及整个流程退出共用同一失效机制。

## CardDetecting

```swift
protocol CardDetecting: Sendable {
    func detectCard(in image: CGImage, orientation: CGImagePropertyOrientation) throws -> Quad?
}
```

- 返回 `nil` 表示没有可信矩形，调用方用 `Quad.fullFrame`。
- 内部按 `confidenceLevels [0.75, 0.55, 0.35]` 逐级放宽。
- 产品长边/短边区间为 1.25–2.4，转换成 Vision 的短边/长边区间约 0.417–0.8。

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

CardLibraryModel 的 add/update/delete/ensureTag/deleteTag/setTags 均 throws；先保存候选库，成功后才发布内存状态。add 可同时接收原图/校正图 Data，失败清理本次新图片；delete 在 JSON 成功后清理无引用图片。加载损坏时禁止覆盖旧库。调用 UI 留在当前表单并显示错误，不能静默关闭。

`loadErrorMessage` 只表示读取失败，区别于保存操作错误。首页展示该错误并提供 `reload()` 重试，恢复前禁用扫描；重试不删除或重建原库，成功后清除错误并发布读取到的记录。

VCardDocument 是当前已保存名片的 Transferable 值；分享时生成新文件，使用 UUID 目录/文件名，编辑后以及同名联系人之间不会复用旧内容。

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

仅在 ui-testing 模式启用 persistent-test-id（UUID）与 reset-test-store，使用独立的 Application Support/UITests 子库验证真实进程重启。fail-store-save、fail-recognition、empty-recognition 仅用于失败分支注入，不影响正常库。
`fail-store-load-once` 同样只在 ui-testing 模式启用：首次读取抛错，重试读取原有库，验证错误展示与恢复。
