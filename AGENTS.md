# AGENTS.md — 工程契约（换会话 / 换 Agent 必读）

> 本文件是本仓库的**唯一事实来源**。任何 agent（人或 AI）在改代码之前，先读完这一页。
> 最后更新：2026-10-27。

---

## 1. 项目是什么

课程作业：用 SDD（规格驱动开发）100% 黑盒复刻「名片全能王 CamCard」的
**名片数字化 + 联系人管理**功能切片。评分看的是"能不能用规格和测试证明它按预期工作"，
不是"功能有没有"。

- 作业原文：`移动应用开发课程作业-v2.pdf`
- 调研与执行方案：`00-作业调研与执行方案.md`
- 交付物与验收：`docs/spec/acceptance.md`

**硬截止：2026-11-06。** 时间不够时优先保「确定性 20 条」，再保「OCR 量化分析」。

## 2. 技术栈与边界（不要随意更换）

| 关注点 | 选型 | 为什么（详见 ADR） |
|---|---|---|
| UI | SwiftUI，iOS 17+ | 最少代码，自带预览与截图能力 |
| 状态 | `@Observable` + `enum State` | 状态一致性可测 |
| 持久化 | **自写 `Codable` + JSON/文件**，不用 SwiftData | ADR-0003：可检查、可 diff、无迁移风险 |
| OCR | Apple **Vision** `VNRecognizeTextRequest` | ADR-0001：离线、确定性、免费 |
| 名片边界 | `VNDetectRectanglesRequest` | 同上，长宽比 1.585 约束 |
| 透视校正 | Core Image `CIPerspectiveCorrection` | 官方能力，无需自研 CV |
| 联系人导出 | Contacts + `CNContactVCardSerialization` | 系统能力，作业允许（`CNContactVCardRepresentation` 只有 macOS 有） |
| 字段解析 | **纯规则 + 正则 + 打分**，不用 LLM | ADR-0002：确定性、可解释、可回归 |
| 工程生成 | XcodeGen（`project.yml`） | `.xcodeproj` 不入库，避免合并冲突 |
| 测试 | XCTest + XCUITest | 官方，CI 可跑 |

**禁止**：引入第三方 SPM 依赖（除测试辅助）、调用云 OCR/LLM API、把 `.xcodeproj` 提交进库、
用 SwiftData 重写数据层（除非先写 ADR 并改测试）。

## 3. 目录地图

```
Sources/
  App/            入口、DI 容器（AppServices）、RootView
  Models/         领域模型（BusinessCard / PhoneNumber / CardDraft / OCRResult / ParsedCard）
  Persistence/    CardStore 协议 + 文件实现 + 内存实现 + CardLibraryModel（唯一写入口）
  Services/
    Recognition/  Vision OCR、边界检测、透视校正、Quad 几何
    Parsing/      TextNormalizer · PhoneClassifier · KeywordTables · HeuristicFieldParser
    Export/       vCard 与通讯录写入
    Imaging/      图片编解码、相机权限协议
  Features/       CardList · Scanner · Crop · Review · Detail · Shared(表单/标签)
  DesignSystem/   主题、TagChip、EmptyState
  Support/        A11y 常量、UITest 配置、Fixture、Demo 数据
Tests/Unit        纯逻辑单测（解析器、仓库、导出…）
Tests/Integration 语料评测（ParserBenchmarkTests + VisionOCRTests 全链路）
UITests           T01–T20 的 XCUITest
Scripts/          合成名片生成、评测、构建脚本
TestData/         50 张名片 + ground_truth.json（**唯一测试语料**）
docs/             spec / api / architecture / testing / guides / reports
```

## 4. 三条不可违反的产品规则

1. **不虚构字段。** 名片上没有 Website 就返回 `nil`（T09）。任何"合理猜测"都是 bug。
   - 实现位置：`BusinessCardFieldParser.dropLowConfidence` + 每条规则的 evidence 记录。
2. **AI 的输出不是数据。** OCR/解析结果必须经过 `ReviewView` 的人工确认才能落库。
3. **重启必须还在。** 任何写操作都必须立刻经 `CardLibraryModel` → `CardStore` 落盘（T18）。

## 5. 命令

```bash
make bootstrap     # 生成 CamCardReplica.xcodeproj（改动 project.yml 后必跑）
make build         # 编译 Debug
make test          # 单元 + 集成测试
make test-ui       # T01–T20（需要模拟器）
make bench         # Ground Truth 准确率，结果贴进 docs/reports/ocr-accuracy.md
make lint          # swiftformat --lint + swiftlint
make format        # 自动格式化
make verify        # lint + build + test（提交前必须全绿）
make testdata      # 重新生成 TestData（会改变语料，非必要不要跑）
```

要求：**提交前 `make verify` 必须通过。** 只跑单个测试：
`make test` 会跑全量；单测可用
`xcodebuild test -scheme CamCardReplica -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:CamCardReplicaTests/FieldParserTests`

## 6. 提交规范（强制）

- 只允许 **Conventional Commits**，由 `.githooks/commit-msg` 校验：
  `type(scope): subject`，type ∈ `feat|fix|refactor|test|docs|build|ci|chore|perf|style`。
- 提交信息正文要写 `Refs: T08` 或 `Spec: docs/spec/product-spec.md#7.5`。
- 一次提交只做一件事；**改解析规则必须同时改/加测试**。
- 例：`fix(parser): treat "…Partners" as company not job title` / `Refs: T08`

## 7. 改动工作流（按这个顺序做，别跳）

1. 读相关 spec 章节 → 2. 写/改测试（红）→ 3. 改实现（绿）→ 4. `make verify` →
5. 更新 `docs/spec/acceptance.md` 的追溯表 → 6. 提交。

新增字段时还要改：`CardField`、`CardDraft`、`CardFieldsForm`、`BusinessCardDetail`、
`ContactsExporter`、`docs/spec/data-model.md`。

## 8. 测试与语料的约定

- 语料在 `TestData/`，由 `Scripts/generate_test_cards.py` 生成（确定性 seed=20261027）。
  **不要手工改 PNG**，要改就改脚本并重新生成。
- 所有语料是合成的：域名用 `.example`，号码用 0000 段，禁止真实个人信息。
- 解析器改动后跑 `make bench`，把新数字贴进 `docs/reports/ocr-accuracy.md`（含日期）。
- 已知限制（不要"顺手修"掉，除非同步更新文档）：
  - 无标签的第二、三个号码无法区分 office/fax → 归为 mobile 并标低置信度；
  - 竖排文字、艺术字、强反光识别差；
  - 模拟器没有摄像头，T04 走「测试名片」注入路径。

## 9. 环境事实

- macOS 27.0.1 / Xcode 27.1 / iOS SDK 27.1（runtime 已安装）
- 测试默认目标：**iPhone 18 Pro**（iOS 27.0）；另有 `make test-ipad`（iPad Pro 11-inch M5）验证布局
- 早先 `simctl create` 失败是 Xcode 附加组件没装完；Device Hub 修复后设备已可选
- 机器是 SAP MDM 托管，App Store 安装受策略影响；Xcode 来自 Self Service。
- 部署目标 iOS 17.0；`TARGETED_DEVICE_FAMILY = 1,2`。

## 10. 当前状态（每次大改后更新）

- [x] 语料 50 张 + Ground Truth
- [x] 模型 / 持久化 / 解析器 / Vision 服务 / 导出
- [x] 全部界面骨架（列表/扫描/裁剪/确认/详情）
- [x] `make build` 通过（Xcode 27.1 / iOS 27.0 模拟器 `iPhone 18 Pro`）
- [x] iPad Pro 11-inch (M5) 上同一套 UI 测试也全绿（布局适配已验证）
- [x] 57 个单元/集成测试 + 15 个 UI 测试全绿（2026-10-27）
- [x] 语料准确率与 Vision 全链路结果已写入 `docs/reports/ocr-accuracy.md`
- [ ] T05（真实相册 picker）、T18（真机杀进程）、T19（真机通讯录）手工验收
- [ ] 与正版 CamCard 的截图对比与差异清单
- [ ] 最终报告定稿与演示稿
