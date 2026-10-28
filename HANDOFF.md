# HANDOFF — 给接手审查的 agent

> 你要审的是一个**课程作业仓库**，不是生产项目。
> 这份文件只做一件事：让你在 10 分钟内分清「哪些是验证过的」「哪些只是声称」「哪些明确没做」，
> 避免把时间花在重复验证，或者被文档里的漂亮话误导。
>
> 仓库：`github.com/wendaining/cam-card-replica`（private）｜分支：`main`
> 本文件对应提交：`a453ced`（提交总数 50）

---

## 0. 30 秒了解全局

用 SwiftUI + Apple Vision 复刻「名片全能王 CamCard」的「名片数字化 + 联系人管理」功能切片：

```
拍/导入 → 确认照片 → 边界检测 → 透视校正 → OCR → 8 字段解析
        → 人工确认 → 保存 → 名片夹 → 搜索/标签 → 详情/编辑
        → 杀进程仍在 → 导出 vCard/通讯录
```

代码规模：48 个源文件、12 个测试文件、2 个 UI 测试文件；65 个单元/集成测试、16 个验收场景。

**这个作业的评分点不是"功能有没有"，而是"能不能用规格和测试证明它按预期工作"。**
所以仓库里一半是代码，一半是文档 + 语料 + 评测。

---

## 1. 五分钟自己跑一遍（不要相信我写的数字）

```bash
brew install xcodegen          # 仅首次
make bootstrap                 # project.yml -> CamCardReplica.xcodeproj
make verify                    # swiftlint + build + 65 个测试
make test-ui                   # 16 个验收场景（约 3 分钟）
make bench                     # 语料准确率，输出 field,correct,total,accuracy 与切片表
```

**期望结果（2026-10-28 本地实测，macOS 27.0.1 / Xcode 27.1 / iPhone 18 Pro）**

| 命令 | 期望结尾 |
|---|---|
| `make verify` | `** TEST SUCCEEDED **`，`Executed 65 tests, with 0 failures` |
| `make test-ui` | `Executed 17 tests, with 0 failures`（16 场景 + 1 截图用例） |
| `make bench` | `name/company/jobTitle/email/website/address` 均 1.000，`phone_fax` 0.900 |

数字对不上就是有人改了代码没改文档——**以你跑出来的为准，然后提 issue/pr 改文档**。

---

## 2. 文档地图：哪份是权威，哪份是历史

| 文档 | 地位 | 怎么用 |
|---|---|---|
| `AGENTS.md` | **权威**：技术栈、命令、提交规范、当前状态、已知限制 | 改代码前必读；与代码冲突时以代码为准并修文档 |
| `docs/spec/product-spec.md` | **权威**：产品规格，条款带编号（7.5.3 这种） | 测试与实现的依据 |
| `docs/spec/conformance-audit.md` | **权威**：作业条款逐条核对（✅/⚠️/❌/➖ + 证据） | 判断"作业要求做了没有"看这份 |
| `docs/spec/acceptance.md` | **权威**：T01–T20 ↔ 测试 ↔ 代码 | 追溯用 |
| `docs/spec/data-model.md` | **权威**：字段定义与判定规则 | 改字段必改 |
| `docs/api/services.md` | **权威**：七个服务协议 | 改接口必改 |
| `docs/architecture/*` + 5 篇 ADR | **权威**：为什么这样选 | 别改结论，除非有更好的方案并新增 ADR |
| `docs/testing/*` | **权威**：测试分层、语料说明、设备矩阵 | |
| `docs/reports/ocr-accuracy.md` | **实测数据**，带命令和日期 | 数字有疑问就重跑 `make bench` |
| `docs/reports/final-report.md` | 结课报告草稿 | 还在补 |
| `docs/reports/demo-script.md` | 演示稿（90 秒主线 + 答辩问答） | |
| `docs/guides/first-run.md` | 给"人"的上手指南 | |
| `docs/guides/environment.md` | 环境搭建与排障 | |
| `00-作业调研与执行方案.md` | ⚠️ **历史文档（写于动手之前）** | 里面的目录结构/排期是设想，**不是 spec**，文首已有警示 |
| `移动应用开发课程作业-v2.pdf` | 作业原文 | 一切要求的源头 |

---

## 3. 什么被验证过，什么没有（最重要的一节）

### ✅ 真实跑过、可以复现

| 断言 | 证据 |
|---|---|
| 编译通过、65 个单元/集成测试全绿 | `make verify` |
| 16 个验收场景在某台 iPhone 18 Pro 模拟器上全绿 | `make test-ui` |
| 同一套 UI 测试在 iPad Pro 11-inch (M5) 上全绿 | `make test-ipad` |
| 字段准确率与幻觉率（50 张语料） | `make bench`，写进 `docs/reports/ocr-accuracy.md` |
| 语料可复现：两次 `--clean` 生成的文件 `shasum` 完全一致 | `docs/testing/strategy.md` 有说明与做法 |
| 遮挡样本（10 张 + 4 张照片遮挡）不影响姓名/公司提取 | `VisionOCRTests` 打印的表 + `CardDetectorTests` |
| `make verify` 通过 | 2026-10-28 本地实跑 |

### ⚠️ 只在模拟器上验证过，真机没验

- **真实相机**：模拟器没有摄像头，T04 走的是「测试名片」注入同一条代码路径。
  真机上的 `AVCaptureSession` 预览、对焦、闪光灯**没有被任何人跑过**。
- **真实系统权限弹窗**：T03 用 stub 注入 `denied` 验证 UI 分支；真机弹窗没验。
- **写入系统通讯录**：`ContactsExporterTests` 只验了数据映射与 vCard 内容，
  `CNContactStore.execute` 在真机上没跑过。
- **杀进程重启**：单元测试用"重建 store"模拟；真机 kill 没验（不过 `make relaunch` 在模拟器里可以验）。

### ❌ 完全没有验证

- **与正版 CamCard 的行为一致性**。仓库里没有任何参考 App 的截图/录屏，
  `docs/reports/difference-analysis.md` 还是**空模板**。
  —— 这是这门课的核心评分点之一，目前**没有证据**。别把它当成已完成。
- **字体多样性**：语料实际只用了 3 种字体（Hiragino / STHeiti / Arial），
  文档里"不同字体"的覆盖是弱的。
- **竖排文字**：只有竖版**版式**，没有竖排**文字**。已知限制，见 `AGENTS.md` §8。
- **真实拍摄质量**：语料的"照片变体"是合成透视+噪声，不是真实手机拍摄的模糊/反光/阴影。

### 🔧 环境差异（会让你看到不同结果）

| | 本地（开发机） | CI |
|---|---|---|
| macOS | 27.0.1 | 15.x |
| Xcode | 27.1 | 16.x |
| 模拟器 | iPhone 18 Pro (iOS 27.0) | 由 `simctl` JSON 选第一个 iPhone |

后果：**CI 用的编译器更老**，本地的某些写法会在 CI 上编译失败（已经踩过一次：
一行十元素的表达式让 Xcode 16 的类型检查器超时）。改代码后最好看一次 CI。

---

## 4. 已知缺口（作业条款层面）

来自 `docs/spec/conformance-audit.md`，只剩 3 处，都是低优先：

| # | 缺口 | 说明 | 建议 |
|---|---|---|---|
| 1 | 字体只有 3 种 | 作业要求"不同字体" | 扩充字体池重生成语料（脚本已支持） |
| 2 | 不支持竖排文字 | 只有竖版版式 | 写进限制，不建议硬做 |
| 3 | 可选字段 Postal Code 未单独建模 | 邮编保留在 `address` 字符串里 | 作业标为可选 |

已经补掉的 4 处（有提交记录可查）：拍摄结果预览页、EXIF 方向校正、查看原始名片、删除标签入口。

---

## 5. 建议你重点质疑的地方

按"最容易出错"排序：

1. **准确率数字是不是在自欺**。`ParserBenchmarkTests` 喂给解析器的是**由 Ground Truth 拼出来的文本**，
   不是真的 OCR 输出——所以那 100% 衡量的是"文本→字段"，不是"图像→字段"。
   图像层只有 9 张 fixture 的结果（`VisionOCRTests`）。文档里写了这个边界，请确认它没被说成"OCR 100%"。
2. **"16 个场景 100% 通过"是不是真的跑过**。跑一次 `make test-ui`，看是不是 17 个方法全绿。
3. **有没有为了过测试而写死的东西**。重点看 `Sources/Services/Parsing/KeywordTables.swift`
   （词表）和 `BusinessCardFieldParser` 的阈值逻辑，判断是不是过拟合到语料。
4. **文档里的文件路径/类型名是不是都存在**。我做过一次机器审计（24 篇文档），
   修掉了悬空引用；你可以再跑一遍，脚本思路见本文附录。
5. **`docs/reports/difference-analysis.md` 是空的**。如果报告里出现"与 CamCard 一致"的说法，那是没证据的。

---

## 6. 数字从哪来（别信手抄的）

```bash
# 测试数量
xcodebuild test ... -only-testing:CamCardReplicaTests | grep "Executed .* tests"
# 语料规模
python3 -c "import json;d=json.load(open('TestData/ground-truth/ground_truth.json'));print(d['card_count'], len(d['cards']))"
# 准确率
make bench 2>&1 | sed -n '/^field,/,/^$/p'
# 文档与代码一致性（自写小脚本，见附录）
```

---

## 7. 协作约定（别破坏）

- **提交信息**必须是 Conventional Commits，`.githooks/commit-msg` 会拦。
  安装：`make hooks`。正文建议带 `Refs: T08` 或 `Spec: docs/spec/product-spec.md#7.5`。
- **改动顺序**：读 spec → 改/加测试（红）→ 改实现（绿）→ `make verify` → 更新追溯表 → 提交。
- `CamCardReplica.xcodeproj` **不入库**（XcodeGen 生成）。改了 `project.yml` 或增删文件后必须 `make bootstrap`。
- 语料不要手工改图，改 `Scripts/generate_test_cards.py` 再 `make testdata`；
  改完必须确认两次生成 `shasum` 一致。
- 不引第三方依赖、不调云 OCR/LLM、不改判分口径（除非有 ADR）。

---

## 8. 一句话总结

**代码和测试是真的（可复现），文档是尽力对齐代码的（做过一次机器审计），
但"与正版 CamCard 行为一致"这件事目前没有证据。**
审查时请把这三件事分开看。

---

### 附录：文档一致性审计脚本（可重跑）

```python
# 提取文档里所有被反引号包住的仓库路径、类型名、make 子命令
# 逐个检查：路径存在？make 子命令在 Makefile 里？测试方法在 Tests/UITests 里？
# 再对数字断言（"65 个单元/集成测试"/"76 张图"）与仓库事实比对。
```
完整版在 `Scripts/audit_docs.py`，直接 `python3 Scripts/audit_docs.py` 即可（退出码非 0 表示有问题）。
它检查：悬空路径 / 不存在的 make 子命令 / 不存在的测试方法 / 与仓库不符的数字。
上一轮跑了之后修掉了：3 个不存在的测试类名、1 个不存在的文档路径、2 处过期数字。
