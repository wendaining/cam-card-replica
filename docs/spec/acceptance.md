# 验收追溯矩阵

每条场景 = 作业第十七节的一条 Reference Test。**确定性的 20 条必须 100% 通过。**

| # | 场景 | 规格 | 自动化测试 | 主要实现 |
|---|---|---|---|---|
| T01 | 首次启动显示空状态 | 7.1.1 | `CardFlowUITests.testT01_*` | `CardListView` |
| T02 | 进入扫描页 | 7.2 | `testT02_*` | `ScannerFlowView` |
| T03 | 相机权限拒绝 | 7.2.1 | `testT03_*` + `CameraPermissionTests` | `SystemCameraPermission` / `StubCameraPermission` |
| T04 | 拍摄进入识别 | 7.2.2 | `testT04_*` | `CameraController` / fixture 注入 |
| T05 | 相册导入 | 7.2.3 | ✅ 系统 PhotosPicker 选取/取消手动留证（2026-10-28）；导入后识别到确认 | `PhotosPicker` → `handle(image:)` |
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
| T18 | 杀进程重启保持 | 12.2–4 | `testT18_processRelaunchKeepsEditsTagsNotesAndBothImages` + 文件库完整回读；真机待验 | `FileCardStore` |
| T19 | 导出 vCard/通讯录 | 13.1–2 | `ContactsExporterTests` + `VCardDocumentTests`（编辑后完整 VCF 重读）；通讯录落库待真机 | `ContactsExporter` / `VCardDocument` |
| T20 | 异常路径 | 4 节 | `testT20_*`、`testT03_*`、`testT06_*` | 各状态机 |

## 概率性功能（不算"通过率"，算准确率）

| 指标 | 目标 | 证据 |
|---|---|---|
| 理想文本首值历史门槛（不是图像准确率） | name/company/email/website/address ≥ 98%，office ≥ 95%，fax ≥ 85% | `ParserBenchmarkTests` 原门槛保留 |
| 缺网站历史门槛 | 误填 0% | missing_website_legacy（仅缺网站） |
| 完整多值/全部缺失字段/真实76张图 | 比较完整集合、漏值、多值、误填；已知歧义也计错，不声称全部为零 | `ImageCorpusTests` + image-accuracy-latest 报告 |
| 照片变体（斜拍/阴影） | 单独统计，不计入通过率 | `docs/reports/ocr-accuracy.md` |

## 手工验收（需截图存档）

- T18 真机 / 模拟器：保存 → 上滑杀进程 → 重开 → 名片、修改、标签、备注、图片都在。
- T03 真机：真实系统权限弹窗「允许/不允许」两条路径。
- T19 真机：写入通讯录后打开「通讯录」核对字段。
- UI 一致性：与参考 App 的页面截图并排对比（见 `docs/reports/`）。

## 2026-10-28 审查修复追溯

| 问题 | 回归证据 | 对应实现 |
|---|---|---|
| R01 保存/编辑/删除失败与图片一致性 | `CardLibraryModelTests` 失败 store、第二张图片失败、重试、完整文件回读；`testT20_storageFailureKeepsReviewAndShowsReason` | 候选库提交后发布，新增失败清图、删除提交后清图 |
| R02 原图入口 | `testT13_savedImageOpensAndCanSwitchToOriginal` | detail-image 按钮、全屏查看器 |
| R03 编辑后导出 | `VCardDocumentTests` 最新记录 VCF 全字段反序列化、同名隔离 | 按当前值生成 Transferable 文件 |
| R04–R07 比例/标签/邮箱数字/网址 | `CardDetectorTests` 宽卡与方形、`PhoneClassifierTests`、`FieldParserTests` | Vision 比例倒数、最近号码标签、受保护区间、完整 host |
| R08–R10 标签/删除确认/取消 | 标签大小写与原子草稿单测；`testT17_swipeDeleteCanBeCancelled`、`testT20_cancelDoesNotCreateDraftTag` | 规范标签、草稿事务、两入口确认、一次取消 |
| R11–R12 错误与后台取消 | `ScanFlowModelTests` 主线程响应与迟到结果；`testT20_recognitionFailureShowsRetryAndRetake`、空识别用例 | 后台任务、token、裁剪错误提示 |
| R14–R16 测量/快照/字体 | `ImageCorpusTests` 全图、完整集合计分器；`RecognitionSnapshotTests`；Python 字体与可复现检查 | Codable 快照、语料 v2、报告导出 |
| R17 运行路径 | Scripts/test_tooling.py；make run 实际安装验证 | 统一 derivedDataPath 与产品路径 |

T05 系统 PhotosPicker 已在模拟器手动完成选取/取消并留存截图；真机与正版的未签收项见 `docs/testing/external-acceptance.md`。方法数不等于20条场景全部签收。

## 2026-10-30 全仓审查修复追溯

| 问题 | 回归证据 | 对应实现 |
|---|---|---|
| R18 邮箱/网址误填组织字段 | `FieldParserTests.testInternetAddressesDoNotInventOrganizationFields`：反例先红；完整 verify 与 bench | 关键词匹配排除邮箱和网址区间，独立组织字段继续识别 |
| R19 联系方式数字误填地址 | `FieldParserTests.testContactDigitsDoNotInventPostalAddress`：邮箱、电话、网址反例及真实地址对照 | 地址打分与邮编检测排除已识别联系方式 |
