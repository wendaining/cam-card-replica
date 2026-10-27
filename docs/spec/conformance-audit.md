# 作业条款逐条核对（Conformance Audit）

> 目的：回答"作业文档里写的功能点，到底实现了没有"。
> 方法：把作业 PDF 第七～十三节的每一条要求拆开，对照代码与测试，给出状态和证据。
> 状态：✅ 已实现 ｜ ⚠️ 部分实现 / 有替代做法 ｜ ❌ 未实现 ｜ ➖ 作业允许不做
> 最近核对：2026-10-27（针对当前 HEAD）

---

## 七.1 名片夹首页

| 要求 | 状态 | 证据 |
|---|---|---|
| 名片列表 | ✅ | `CardListView.listContent` |
| 空名片状态 | ✅ | `EmptyStateView` + 文案「还没有名片」；`testT01` |
| 扫描名片入口 | ✅ | 工具栏 `scanButton`；`testT02` |
| 名片缩略信息（姓名/职位/公司/电话/标签/缩略图） | ✅ | `CardRow` |
| 点击进入名片详情 | ✅ | `NavigationLink(value:)` + `CardDetailView`；`testT13` |
| 搜索入口 | ✅ | 顶部搜索框（不用系统 `.searchable`，为了可被 UI 测试定位） |
| 新增名片后列表更新 | ✅ | `CardLibraryModel.add` 即时写入 + `@Observable` 刷新；`testT11_T12` |
| 删除名片后列表更新 | ✅ | `delete` + `dismiss()`；`testT17` |

## 七.2 拍摄与图片导入

| 要求 | 状态 | 证据 / 说明 |
|---|---|---|
| 相机预览 | ✅ | `CameraPreview`（AVCaptureVideoPreviewLayer） |
| 相机权限申请 | ✅ | `SystemCameraPermission` + 拒绝态 UI（`testT03`） |
| 拍摄按钮 | ✅ | `shutterButton`；`testT04` |
| 返回 | ✅ | 左上「取消」 |
| 取消 | ✅ | 任意阶段取消都退出且不写数据（`testT20`） |
| 重拍 | ✅ | 裁剪页「重新拍摄」→ 回取景（`testT06`） |
| 从照片库导入 | ✅ | `PhotosPicker`；导入后同一条流水线 |
| **拍摄结果预览** | ⚠️ | **没有独立的"这张行不行"确认页**，由裁剪页承担：它显示拍摄结果、允许重拍/调整/确认，等价于预览 + 确认。作业要求的 8 个测试点都有覆盖，但严格说少了一个"只预览不裁剪"的中间页 |
| 确认进入识别 | ✅ | 裁剪页「下一步」 |

测试 8 项对照：

| 作业测试点 | 状态 | 说明 |
|---|---|---|
| 正常拍摄 | ⚠️ | 模拟器无相机，用 fixture 注入跑通同一条代码路径；真机需手工验 |
| 拍摄后确认 | ✅ | `testT04` |
| 拍摄后重拍 | ✅ | `testT06` |
| 拍摄后取消 | ✅ | `testT20` |
| 从相册导入 | ✅ | 手工（系统 picker 无法稳定自动化） |
| 相机权限拒绝 | ✅ | `testT03`（注入 denied）+ 真机手工 |
| **相册权限拒绝** | ➖ | 用的是 `PhotosPicker`，**不需要相册权限**（系统出进程选择器），所以这条路径在 iOS 14+ 不存在。作业写的是通用要求，这里以"不申请权限"作为等价处理 |
| 中途退出 | ✅ | `testT20` |

## 七.3 区域检测与图像校正

| 要求 | 状态 | 证据 |
|---|---|---|
| 自动检测名片边界 | ✅ | `VisionCardDetector`（长宽比 1.25–2.4，三档置信度） |
| 显示检测结果 | ✅ | `QuadOverlay` 蓝色四边形 + 四角手柄 |
| 自动裁剪 | ✅ | 确认后按四角做透视校正并裁掉外部 |
| 透视校正 | ✅ | `CoreImageCardCorrector`（`CIPerspectiveCorrection`） |
| **方向校正** | ✅ | **本轮修复**：EXIF 方向在入口归一（`ImageCoding.applyingOrientation`）。此前检测用方向参数、校正用原始像素，旋转照片会歪。新增 4 个测试 `ImageCodingTests` |
| 手动调整 | ✅ | 四角可拖，坐标钳制在图片内（`CardDetectorTests.testClamping…`） |
| 确认 | ✅ | `cropConfirm` |
| 重新拍摄 | ✅ | `cropRetake` |

测试数据覆盖（作业列的 8 类）：

| 类型 | 覆盖 | 说明 |
|---|---|---|
| 正面拍摄 | ✅ | 50 张干净渲染 |
| 倾斜拍摄 | ✅ | 12 张 photo 变体（透视 + 旋转 ±6°） |
| 轻微旋转 | ✅ | 同上 |
| 深色背景 | ✅ | 深色纸面 + 深色桌面 |
| 浅色背景 | ✅ | `ivory` / `white` / `paper` |
| 带阴影 | ✅ | photo 变体有投影 + 雾面 |
| **边缘部分遮挡** | ✅ | 10 张 `occluded`（手指压角、只覆盖页边距）+ 4 张 `occluded-photo`（桌上名片 + 手指）；`CardDetectorTests.testDetectsCardWithOneCornerOccluded` 验证轮廓被切断仍可检出 |
| 复杂桌面 | ✅ | 木纹/深色/蓝灰随机背景与杂乱纹理 |

## 七.4 OCR 文字识别

| 要求 | 状态 | 说明 |
|---|---|---|
| 中文 / 英文 / 中英双语 | ✅ | 语料 15 / 15 / 20 |
| 横版 | ✅ | 1012×638 |
| **竖版** | ⚠️ | 有竖版**版式**（638×1012，`zh-04` 等），但**不支持竖排文字**（日式竖书）。Vision 本身对竖排也弱 |
| 不同字体 | ⚠️ | 实际只用了 Hiragino Sans GB / STHeiti / Arial 三种，不是"不同字体"的充分覆盖 |
| 不同字号 | ✅ | 姓名 40–46pt 到正文 16–19pt |
| 不同版式 | ✅ | 左对齐/居中/两栏/竖版/极简 五种 |
| 多电话号码 | ✅ | 最多 3 个（手机+座机+传真） |
| 多 Email | ✅ | 部分卡 2 个 |
| 部分字段缺失 | ✅ | `expected_absent` 15 张 |
| 复杂背景 / Logo 较多 | ✅ | 4 种 Logo 样式 + 深色底 |

必须保留的处理链（作业原文）：

| 环节 | 状态 | 证据 |
|---|---|---|
| 原始名片 | ✅ | `originalImageID` + 详情页「原图」切换（本轮补） |
| OCR Raw Text | ✅ | `OCRResult.rawText` → 确认页「查看识别原文」（含逐行置信度） |
| Structured Fields | ✅ | `HeuristicFieldParser` → `ParsedCard` |
| Manual Correction | ✅ | `ReviewView` |
| Final Contact | ✅ | `BusinessCard` |

## 七.5 联系人结构化字段

| 字段 | 状态 | 说明 |
|---|---|---|
| Name / Company / Job Title / Mobile / Office Phone / Email / Website / Address | ✅ 8/8 | 见 `docs/reports/ocr-accuracy.md` |
| 可选：Department | ✅ | |
| 可选：Fax | ✅ | |
| 可选：**Postal Code** | ❌ | 未单独建模；邮编被当作地址的一部分保留在 `address` 里 |
| 可选：Notes | ✅ | |

## 八 AI 的能力边界（作业要求主动测试）

| 场景 | 状态 | 说明 |
|---|---|---|
| 字段歧义（如 "Apple" 是公司/产品/地址） | ⚠️ | 没有专门语料。当前策略：无机构关键词的孤立行按"字号最大且无其他特征"判为姓名。已加测试固定该行为，**不硬编码特殊词**（否则就是过拟合） |
| 人名与公司混淆（Jordan Lee / Lee Consulting） | ✅ | `FieldParserTests.testPersonNameIsNotCompany` |
| 多电话判断 Mobile/Office/Fax | ✅ | 标签优先；无标签时**不猜**，见准确率报告 |
| 中英文混排 | ✅ | `TextNormalizer.separateScriptRuns` |
| 字段缺失不得凭空产生 | ✅ | 15 张 `expected_absent`，幻觉率 **0%** |

## 九 人工校正

| 要求 | 状态 | 证据 |
|---|---|---|
| 可修改姓名/公司/职位/手机/电话/Email/Website/地址 | ✅ | `CardFieldsForm` |
| 空字段 | ✅ | 留空即 `nil`，保存时过滤 |
| 多电话 / 多 Email | ✅ | 可增删、可分类 |
| 错误字段 / OCR 错字 | ✅ | 直接改；低置信字段标「请确认」 |
| 用户修改后保存 | ✅ | `CardDraft.makeCard` |
| 取消修改 | ✅ | 取消不落库 |

## 十 保存与详情

| 要求 | 状态 | 证据 |
|---|---|---|
| `originalImage` / `processedImage` | ✅ | 两张图都落盘 |
| 八个字段 + tags + notes + createdAt | ✅ | `BusinessCard` |
| **查看原始名片** | ✅ | **本轮补**：详情页点图片 → 全屏查看器，可在「校正图 / 原图」间切换 |
| 查看识别字段 | ✅ | 详情页 |
| 编辑 / 保存 / 删除 / 返回 | ✅ | |
| 点电话号码 / Email / Website | ✅ | `tel:` / `mailto:` / `https:` |

## 十一 搜索与基本管理

| 要求 | 状态 | 说明 |
|---|---|---|
| 按姓名 / 公司 / 职位 / 电话 / Email 搜索 | ✅ | `BusinessCard.matches(query:)`，另加标签与备注 |
| 创建标签 | ✅ | 确认页 / 编辑页「新建标签」 |
| 给名片添加标签 | ✅ | `TagPickerView` |
| 按标签查看 | ✅ | 列表顶部标签条 |
| **删除标签** | ✅ | **本轮补**：标签区「删除标签」菜单 → 从所有名片移除并将其从库中删除（`deleteTag` 早已实现，缺的是入口） |
| 备注 | ✅ | |

## 十二 本地持久化

| 要求 | 状态 | 证据 |
|---|---|---|
| 保存 → Kill App → 重开 → 找到该名片 | ✅ | `FileCardStore` + `testPersistenceRoundTripThroughFileStore`；手工路径 `make relaunch` |
| 原始图像仍在 | ✅ | `Images/<uuid>.jpg` |
| 修改后的字段仍在 | ✅ | |
| 标签 / 备注仍在 | ✅ | |

## 十三 联系人导出

| 要求 | 状态 | 证据 |
|---|---|---|
| 保存到系统联系人 | ✅ | `ContactsExporter.saveToContacts` |
| 导出 VCF/vCard | ✅ | `CNContactVCardSerialization` + 分享面板 |
| 字段映射（姓名/公司/职位/电话/Email/地址） | ✅ | `ContactsExporterTests.testContactMappingCarriesEveryField` + vCard 内容断言 |

---

## 结论：还差什么

**作业要求的功能点里，只有 5 处不是"完整实现"：**

| # | 缺口 | 严重程度 | 建议 |
|---|---|---|---|
| 1 | 没有独立的「拍摄结果预览」页（由裁剪页承担） | 低 | 若老师严格要求，加一个只显示照片 + 「用这张/重拍」的中间页，约 40 行 |
| 2 | 语料缺「名片边缘被部分遮挡」样本 | 中 | 生成器加一层"手指/物体遮住一角"的合成，重跑评测 |
| 3 | 不支持竖排文字（只有竖版版式） | 中 | Vision 对竖排也弱；建议写进"已知限制"，不作为承诺 |
| 4 | 字体覆盖只有 3 种 | 低 | 生成器加字形变化（粗细/衬线），或直接用系统可用字体池 |
| 5 | 可选字段 Postal Code 未单独建模 | 低 | 作业标为可选；邮编已保留在地址字符串中 |

**这一轮已经补掉的 3 个真实缺口**（都是"实现有、入口没有"或"逻辑有、坐标算错"）：

1. **方向校正**：EXIF 旋转的照片，检测用带方向的坐标、校正用原始像素 → 会歪。现在入口统一归一。
2. **查看原始名片**：`originalImageID` 一直存着，但详情页没有入口。现在点图片可切「校正图/原图」。
3. **删除标签**：`deleteTag` 早就有，UI 没暴露。现在标签区有「删除标签」菜单。

> 这三条说明一件事：**"作业文档里写了"和"用户点得到"之间还有距离**。审计的价值就在这里——
> 功能表打勾不等于能用。
