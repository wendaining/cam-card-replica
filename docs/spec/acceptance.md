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

课程原始用例来源及边界见 [参考测试套件](../testing/reference-test-suite.md)。T19 采用导出自动测试证据，T18 采用模拟器回归；本人操作清单记录其他待验证项目。

## 概率性功能（不算"通过率"，算准确率）

| 指标 | 目标 | 证据 |
|---|---|---|
| 理想文本首值历史门槛 | name/company/email/website/address ≥ 98%，office ≥ 95%，fax ≥ 85% | `ParserBenchmarkTests` 原门槛保留 |
| 缺网站历史门槛 | 误填 0% | missing_website_legacy（仅缺网站） |
| 完整多值/全部缺失字段/真实76张图 | 比较完整集合、漏值、多值、误填；已知歧义也计错，不声称全部为零 | `ImageCorpusTests` + image-accuracy-latest 报告 |
| 照片变体（斜拍/阴影） | 单独统计，不计入通过率 | `docs/reports/ocr-accuracy.md` |

## 本人补充的验收记录

- T18 真机 / 模拟器：保存 → 终止进程 → 重新打开 → 名片、修改、标签、备注、图片都在。
- T03 模拟器：真实系统权限弹窗「允许/不允许」两条路径，以及已有授权/拒绝状态，四项专项已通过。
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
| R18 邮箱/网址误填组织字段 | `FieldParserTests.testInternetAddressesDoNotInventOrganizationFields`、`testDottedCompanySuffixSurvivesInternetAddressMasking`：反例先红；完整 verify 与 bench | 关键词匹配排除邮箱和网址区间；保留带公司名的连写法律后缀 |
| R19 联系方式数字误填地址 | `FieldParserTests.testContactDigitsDoNotInventPostalAddress`：邮箱、电话、网址反例及真实地址对照 | 地址打分与邮编检测排除已识别联系方式 |
| R20 负分公司候选误作职位 | `FieldParserTests.testNegativeTitleCandidateRemainsACompany`：中英文公司、有/无独立职位对照 | 职位净分必须大于零，否则保留给公司提取 |
| R21 短英文地址漏提取 | `FieldParserTests.testShortStreetAddressUsesLabelOrHouseNumberEvidence`：标签/无标签、门牌号、空标签与孤立街道词 | 地址标签和门牌号参与证据打分，保留联系方式排除规则 |
| R22 座机/传真同号丢类型 | `FieldParserTests.testSharedOfficeAndFaxNumberPreservesBothKinds`：正反顺序、同行、格式重复、草稿到导出 | 按号码类型和数字共同去重 |
| R23 相册迟到结果覆盖草稿 | `ScanFlowModelTests`：正常导入/错误、旧成功与失败、替换选择、重拍与 Task 取消 | 相册异步加载进入流程模型，共用 operationID 失效检查 |
| R24 读取失败伪装成空库 | `CardLibraryModelTests.testReloadRecoversReadFailureWithoutReplacingStoredCards`；`testT20_libraryLoadFailureShowsRetryInsteadOfEmptyState` | 独立加载错误状态、首页错误/重试入口、恢复前禁用扫描 |
| R25 整图路径无谓重采样 | `CardDetectorTests.testWholeImageCorrectionPreservesDecodedPixels`：深/浅底 fixture 像素回读先红后绿 | fullFrame 直接保留归一方向后的输入图像 |

## 歧义字段测试补充（2026-10-30）

| 课程要求 | 自动化证据 | 行为 |
|---|---|---|
| 第八节字段歧义，T08/T09/T11 | FieldParserTests.testAmbiguousWordAloneDoesNotInventAContact | 孤立 Apple 无联系方式或机构证据，保留未归类文字，不生成联系人 |
| 第八节上下文与人工核对 | FieldParserTests.testAmbiguousCompanyUsesContextAndRequiresReview | 姓名后的 Apple 可作公司候选，但必须低置信提示；不补网站、地址、职位 |
| 第八节语义冲突 | FieldParserTests.testAmbiguousWordInAddressDoesNotBecomeCompany | Address: 42 Apple Road 保留为地址，不误作公司 |

本轮仅加测试，不修改解析规则或评测语料。

## 2026-11-07 提交前复核

Xcode 27.2 / iPhone 18 Pro / iOS 27.0：重新生成工程后，make verify 通过（108 个单元/集成方法，0 个非预期失败）；完整 iPhone UI 的 24 个功能方法通过，另 1 个截图方法默认跳过。T18 再次验证真实进程重启后的修改、标签、备注和两张图片。76 张图片的逐图字段测量与已归档 JSON 完全一致。

本次是现有实现回归和规格说明校正，不代表真机相机、系统权限、正版行为或同图识别对比已验收。最终交付缺口、文档核对和命令结果见 [提交前核实](../reports/submission-audit.md)。

## 2026-11-07 OCR 原始证据归档

规格 7.4.5–7.4.6 对应 ImageCorpusTests.testEvidenceRoundTripKeepsRawOCRAndInitialFields、完整图片评测和 Python 证据导出检查。当前 make verify 执行 109 个方法，0 个非预期失败；make bench 的 7 个评测方法通过。76 条记录保留原文、逐行坐标与置信度、初始解析、四角、原图哈希及实际识别输入 PNG。

[原始证据](../reports/evidence/ocr-measurement/README.md)、[完整验证](../reports/verification-local.md)和 [本人填写模板](../submission/final-signoff.md)已关联。真机、正版观察和最终人工确认保留实际状态。

## FauxCam 正常相机接口专项（2026-11-07）

规格 7.2.7 对应 FauxCameraUITests.testT04_fauxCameraShutterRetakeRecognizeAndSave。FauxCam 1.1.0 提供 en-01.png 输入，关闭 fixture-camera，正常快门、预览、重拍、裁剪、Vision、原文与保存通过，18.967 秒。当前 UI 定义包含 27 个方法，专项与截图均有显式启用条件。原生系统授权另有四项模拟器专项通过；实拍质量未验证。

[专项记录](../reports/fauxcam-validation.md)保存工具版本、签名检查、输入条件、截图和测试摘要。

## 2026-11-07 系统权限专项补充

规格 7.2.1 对应 SystemCameraPermissionUITests.testT03_systemCameraPermission。make test-camera-permissions 分别设置已有授权、已有拒绝与未决定状态，并操作真实 SpringBoard 弹窗允许/拒绝。四项通过，未加载 FauxCam；截图、API 探测和摘要见 [系统权限证据](../reports/evidence/permissions/README.md)。

## 2026-11-08 正版同图与证据检查

T05、T08、T09、T10 对应官方 Android CamCard 8.25.0.20260129 Basic 的 76 张固定输入及完整字段集合比较。单图相册、输入哈希、完整表单、重复控件一致性与取消保存均有实际记录。22 项 Python 检查验证界面读取、字段统计和打包拒绝条件；make verify 再次通过 109 个方法。

[同图结果](../reports/reference-comparison.md)、[原始证据](../reports/evidence/reference-android/README.md)与 [T01–T20 参考行为表](../submission/reference-observations.csv)注明 Android 和官网各自范围。正版 iOS、真实拍摄质量与会员导出文件未验证。

正版读取工具的 Nickname 地址归类由 Scripts/test_reference_camcard_ui.py 中的 test_nickname_does_not_become_an_address_component 回归保护；新增测试先失败，修正后通过，原始 XML 重算记录保留。
