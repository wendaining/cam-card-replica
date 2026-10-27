# 验收追溯矩阵

每条场景 = 作业第十七节的一条 Reference Test。**确定性的 20 条必须 100% 通过。**

| # | 场景 | 规格 | 自动化测试 | 主要实现 |
|---|---|---|---|---|
| T01 | 首次启动显示空状态 | 7.1.1 | `CardFlowUITests.testT01_*` | `CardListView` |
| T02 | 进入扫描页 | 7.2 | `testT02_*` | `ScannerFlowView` |
| T03 | 相机权限拒绝 | 7.2.1 | `testT03_*` + `CameraPermissionTests` | `SystemCameraPermission` / `StubCameraPermission` |
| T04 | 拍摄进入识别 | 7.2.2 | `testT04_*` | `CameraController` / fixture 注入 |
| T05 | 相册导入 | 7.2.3 | ⚠️ 手工（系统 picker 无法稳定自动化）；导入后的链路由 `testT04_*` 覆盖 | `PhotosPicker` → `handle(image:)` |
| T06 | 倾斜名片边界检测 | 7.3.1–2 | `testT06_*` + `CardDetectorTests` | `VisionCardDetector` / `CropView` |
| T07 | OCR 产出原文 | 7.4.1–2 | `testT07_T08_*` | `VisionTextRecognizer` |
| T08 | 字段正确分类 | 7.5.1–4 | `FieldParserTests` / `ParserBenchmarkTests` | `HeuristicFieldParser` |
| T09 | 缺失网站不虚构 | 7.5.5 | `testT09_*` + `testMissingWebsiteIsNotInvented` | `dropLowConfidence` |
| T10 | 多电话分类 | 7.5.4 | `testT10_*` + `testMultiplePhonesAreClassifiedByLabel` | `PhoneClassifier` |
| T11 | 人工修改后保存 | 9.1 | `testT11_T12_*` | `ReviewView` |
| T12 | 保存后列表出现 | 7.1.4 | `testT11_T12_*` | `ScanFlowModel.save` |
| T13 | 详情显示全部字段 | 10.2 | `testT13_*` | `CardDetailView` |
| T14 | 编辑后保存 | 10.3 | `testT14_*` | `CardDetailView.saveEdits` |
| T15 | 搜索 | 11.1 | `testT15_*` + `BusinessCardTests` | `matches(query:)` |
| T16 | 标签筛选 | 11.2 | `testT16_*` + `CardLibraryModelTests` | `TagChip` / `cards(matching:tag:)` |
| T17 | 删除 | 7.1.5 | `testT17_*` | `CardLibraryModel.delete` |
| T18 | 杀进程重启保持 | 12.2 | `CardLibraryModelTests.testPersistenceRoundTripThroughFileStore` + 手工 | `FileCardStore` |
| T19 | 导出 vCard/通讯录 | 13.1–2 | `ContactsExporterTests` | `ContactsExporter` |
| T20 | 异常路径 | 4 节 | `testT20_*`、`testT03_*`、`testT06_*` | 各状态机 |

## 概率性功能（不算"通过率"，算准确率）

| 指标 | 目标 | 证据 |
|---|---|---|
| 字段级准确率（50 张语料，干净渲染） | name/company/email/website/address ≥ 98%，office ≥ 95%，fax ≥ 85% | `ParserBenchmarkTests` 输出 |
| 幻觉率（不存在的字段被填） | 0% | `no_hallucination` 指标 |
| 照片变体（斜拍/阴影） | 单独统计，不计入通过率 | `docs/reports/ocr-accuracy.md` |

## 手工验收（需截图存档）

- T18 真机 / 模拟器：保存 → 上滑杀进程 → 重开 → 名片、修改、标签、备注、图片都在。
- T03 真机：真实系统权限弹窗「允许/不允许」两条路径。
- T19 真机：写入通讯录后打开「通讯录」核对字段。
- UI 一致性：与参考 App 的页面截图并排对比（见 `docs/reports/`）。
