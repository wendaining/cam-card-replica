# CamCard Replica

用 **SwiftUI + Apple Vision** 复刻「名片全能王 CamCard」的「名片数字化 + 联系人管理」功能切片。
课程作业要求的是**用规格和测试证明行为等价**，所以这个仓库里代码只是一半，另一半是
`docs/` 下的规格、验收追溯表和实测准确率报告。

```
拍/导入 → 名片检测 → 透视校正 → OCR → 八字段解析 → 人工确认 → 保存
        → 名片夹 → 搜索/标签/备注 → 详情/编辑/删除 → 杀进程仍在 → 导出 vCard/通讯录
```

| | |
|---|---|
| 单元 / 集成测试 | **64 个，全绿**（含 50 张语料的字段准确率评测） |
| 端到端测试 | **15 个场景，全绿**，覆盖 T01–T20（iPhone 18 Pro 与 iPad Pro 11 各跑一遍） |
| 字段准确率 | name/company/title/email/website/address **100%**，office 98%，fax 90%，**幻觉率 0%** |
| 第三方依赖 | **无**（Vision / Core Image / Contacts / SwiftUI 全是系统框架） |

![名片夹](docs/reports/screenshots/02-list.png)

## 5 分钟跑起来

前置：macOS + Xcode（含 iOS 模拟器 runtime）+ `xcodegen`。

```bash
brew install xcodegen          # 一次性，约 10 秒
git clone <this repo> && cd cam-card-replica
make bootstrap                 # 由 project.yml 生成 CamCardReplica.xcodeproj
make build                     # 期望结尾：** BUILD SUCCEEDED **
make test                      # 期望结尾：Executed 64 tests, with 0 failures
open CamCardReplica.xcodeproj  # 选 iPhone 18 Pro，Cmd+R
```

**第一次亲手用**（不写代码，跟着点）：[docs/guides/first-run.md](docs/guides/first-run.md) —
15 分钟走完闭环，顺带验掉 20 条验收里的 15 条。

第一次跑会遇到的两件事：

1. **模拟器没有摄像头**，这是预期的。扫描页会显示提示，用右下角的「测试名片」按钮
   （试管图标）走完整条识别链路，或用左下角从相册导入。
2. 想直接看效果、不想点：`make test-ui` 会跑完 15 条端到端场景，约 2.5 分钟。

截图重新生成：

```bash
touch /tmp/capture-screenshots
xcodebuild test -only-testing:CamCardReplicaUITests/ScreenshotTests
ls /tmp/camcard-shots
```

## 架构

```
                    ┌──────────────── SwiftUI ────────────────┐
                    │ CardList · Scanner · Crop · Review ·    │
                    │ Detail · TagPicker · CardFieldsForm     │
                    └───────────────────┬─────────────────────┘
                                        │ @Bindable / Binding
                    ┌───────────────────▼─────────────────────┐
                    │ ViewModels (@Observable, 主线程状态机)   │
                    │ ScanFlowModel.Stage =                   │
                    │   capture → crop → processing → review  │
                    └───────────────────┬─────────────────────┘
                                        │ 只依赖协议
     ┌──────────────────────────────────▼──────────────────────────────────┐
     │ TextRecognizing · CardDetecting · ImageCorrecting · FieldParsing    │
     │ ContactExporting · CameraPermissionProviding · CardStore            │
     └────┬─────────────┬─────────────┬─────────────┬──────────────┬───────┘
          │             │             │             │              │
      Vision OCR   Vision 矩形    Core Image    规则解析器      Contacts / vCard
                  检测          透视校正       （无 LLM）      JSON + 图片文件
                                        │
                              ┌─────────▼─────────┐
                              │ UI 测试用的替身：  │
                              │ fixture 图 / 桩权限 │
                              │ / 内存存储         │
                              └───────────────────┘
```

三条设计原则，也解释了为什么测试能跑得这么细：

1. **不确定的东西都藏在协议后面**：相机、权限、OCR、检测、导出各有协议，
   测试注入替身，生产路径零 `if debug`（[ADR-0004](docs/architecture/adr/ADR-0004-protocol-seams-and-fixtures.md)）。
2. **单一写入点**：所有变更走 `CardLibraryModel` → `CardStore`，写入即落盘，
   所以「杀进程重启」天然成立（[ADR-0003](docs/architecture/adr/ADR-0003-json-file-persistence.md)）。
3. **解析器是纯函数**：`OCRResult → ParsedCard`，无 IO 无随机，
   50 张语料可以直接当单元测试跑（[ADR-0002](docs/architecture/adr/ADR-0002-rule-based-parser.md)）。

## 功能与验收

| 模块 | 实现 | 对应验收 |
|---|---|---|
| 名片夹（空态/列表/搜索/标签） | `CardListView` | T01, T13, T15, T16 |
| 拍摄 / 相册导入 | `ScannerView` + `AVCaptureSession` / `PhotosPicker` | T02–T05 |
| 边界检测 + 手动四角校正 | `VisionCardDetector` + `CropView` | T06 |
| OCR（中英混排） | `VisionTextRecognizer` | T07 |
| 八字段结构化 | `HeuristicFieldParser` | T08, T09, T10 |
| 人工确认与修改 | `ReviewView` + `CardFieldsForm` | T11 |
| 保存 / 详情 / 编辑 / 删除 | `CardDetailView` | T12–T14, T17 |
| 本地持久化 | `FileCardStore` | T18 |
| 导出 vCard / 通讯录 | `ContactsExporter` | T19 |
| 异常路径 | 各状态机 | T20 |

完整的「需求 ↔ 测试 ↔ 代码」追溯见 [docs/spec/acceptance.md](docs/spec/acceptance.md)。

## 目录

```
Sources/
  App/           入口、DI 容器（AppServices）、RootView
  Models/        BusinessCard / PhoneNumber / CardDraft / OCRResult / ParsedCard
  Persistence/   CardStore 协议 + 文件实现 + 内存实现 + CardLibraryModel
  Services/      Recognition(Vision) · Parsing(规则) · Export(vCard) · Imaging
  Features/      CardList · Scanner · Crop · Review · Detail · Shared
  DesignSystem/  主题、TagChip、EmptyState、readableWidth
  Support/       A11y 标识、UITest 配置、fixture、Demo 数据
Tests/           64 个单元/集成测试（含语料准确率评测）
UITests/         T01–T20 端到端 + 截图用例
TestData/        50 张合成名片 + Ground Truth（确定性生成，可复现）
Scripts/         语料生成、验证脚本
docs/            spec / api / architecture(5 篇 ADR) / testing / guides / reports
```

## 文档

| 先看哪篇 | 内容 |
|---|---|
| [AGENTS.md](AGENTS.md) | 工程契约：约束、命令、提交规范、当前状态（换 agent 先读这个） |
| [docs/spec/product-spec.md](docs/spec/product-spec.md) | 产品规格（编号条款，按作业章节组织） |
| [docs/spec/data-model.md](docs/spec/data-model.md) | `BusinessCard` 模型与每个字段的判定规则 |
| [docs/spec/acceptance.md](docs/spec/acceptance.md) | T01–T20 追溯矩阵 |
| [docs/api/services.md](docs/api/services.md) | 七个服务协议的输入/输出/失败语义 |
| [docs/architecture/overview.md](docs/architecture/overview.md) | 架构与 5 篇 ADR |
| [docs/testing/strategy.md](docs/testing/strategy.md) | 测试分层、语料说明、设备矩阵 |
| [docs/reports/ocr-accuracy.md](docs/reports/ocr-accuracy.md) | 准确率、按维度切分、错误归因 |
| [docs/reports/demo-script.md](docs/reports/demo-script.md) | 90 秒演示脚本 + 答辩问答 |
| [docs/guides/first-run.md](docs/guides/first-run.md) | 第一次上手：三条命令 + 15 分钟验收路线 |
| [docs/guides/environment.md](docs/guides/environment.md) | 环境搭建与排障 |

## 合规

课程作业用途。所有测试名片、人名、公司、电话、邮箱均为**虚构合成数据**
（`.example` 域名、`0000` 号码段），不含任何真实个人信息；
未使用 CamCard 的任何代码、模型或素材。
