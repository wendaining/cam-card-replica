# 架构总览

## 分层

```
View (SwiftUI)
   │ @Bindable / Binding
ViewModel (@Observable, 主线程状态机)
   │ 调用协议
Service 协议层 ── 生产实现（Vision / Core Image / Contacts / AVFoundation）
   │              测试实现（Fixture / Stub / InMemory）
Repository（CardLibraryModel：唯一写入点）
   │
CardStore 协议 ── FileCardStore / InMemoryCardStore
```

## 关键原则

1. **不确定的东西都在协议后面。** 相机、OCR、检测、导出各有协议；
   UI 测试通过 `AppServices.make(arguments:)` 注入替身，生产路径零改动。
2. **单一写入点。** 所有变更走 `CardLibraryModel`，写入即落盘 → T18 自然通过。
3. **状态是枚举，不是布尔堆。** `ScanFlowModel.Stage` 决定当前屏幕，
   不可能出现"裁剪页和确认页同时存在"这种状态。
4. **解析器是纯函数。** 输入 `OCRResult`，输出 `ParsedCard`，无 IO 无随机，
   所以 50 张语料可以当单元测试跑，回归成本接近零。
5. **图片来源可替换。** `ScanFlowModel.handle(image:)` 与相机解耦，
   模拟器/UI 测试走 fixture，真机走 `AVCaptureSession`。

## 数据流（一次扫描）

```
CameraController ──Data──> ImageCoding.cgImage ──CGImage──> ScanFlowModel
  ScanFlowModel ──detect──> Quad (Vision)
  CropView 用户微调 Quad
  ScanFlowModel ──correct──> CGImage (Core Image 透视)
                ──OCR────> OCRResult (Vision)
                ──parse──> ParsedCard (规则)
                ──draft──> ReviewView 人工确认
                ──save───> CardLibraryModel ──> FileCardStore (JSON + JPG)
```

## 并发

- UI 与状态在主 actor；`AVCaptureSession` 的 start/stop 在专用串行队列；
- 拍照回调在任意队列，用独立的 `PhotoCaptureDelegate` 桥接成 `async`，
  不把 UIKit/AVFoundation 类型泄漏进模型层。

## 目录与文件命名

- `Sources/Features/<功能>/<视图|模型>.swift`；一个文件一个主要类型。
- 协议放 `Services/<域>/`，实现同名 + 前缀（`Vision…`、`CoreImage…`、`File…`）。
- 测试文件名与被测类型一致，`Tests/Unit/<Type>Tests.swift`。

## 决策记录

| ADR | 决策 |
|---|---|
| [0001](adr/ADR-0001-vision-for-ocr.md) | OCR 与边界检测用 Apple Vision |
| [0002](adr/ADR-0002-rule-based-parser.md) | 字段抽取用规则，不用 LLM |
| [0003](adr/ADR-0003-json-file-persistence.md) | 持久化用 Codable + 文件，不用 SwiftData |
| [0004](adr/ADR-0004-protocol-seams-and-fixtures.md) | 协议抽象 + fixture 注入换取可测性 |
| [0005](adr/ADR-0005-xcodegen-and-conventional-commits.md) | XcodeGen 生成工程 + Conventional Commits |
