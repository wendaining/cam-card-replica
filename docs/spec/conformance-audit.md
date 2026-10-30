# 作业条款逐条核对（Conformance Audit）

> 2026-10-30 执行范围更新：人工验收暂缓，不作为本轮开发阻塞。T18 沿用模拟器持久化证据；T19 沿用通讯录字段映射和 VCF 回读测试，不追加系统通讯录手动核对。官网对比已整理，但不代表指定版本实测等价。以下未验清单保留为历史/后续选项，不标为已通过。

> 目的：回答"作业文档里写的功能点，到底实现了没有"。
> 方法：把作业 PDF 第七～十三节的每一条要求拆开，对照代码与测试，给出状态和证据。
> 状态：✅ 已实现 ｜ ⚠️ 部分实现 / 有替代做法 ｜ ❌ 未实现 ｜ ➖ 作业允许不做
> 最近核对：2026-10-28。✅ 表示实现或对应自动化证据；真机/正版尚未签收，见文末与外部验收清单。

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
| **拍摄结果预览** | ✅ | **本轮补**：独立的「确认照片」页（`PreviewView`），显示整张照片 + 「重拍 / 使用这张」，通过后进入裁剪。`testT04`、`testT04b_previewCanBeRetaken` |
| 确认进入识别 | ✅ | 裁剪页「下一步」 |

测试 8 项对照：

| 作业测试点 | 状态 | 说明 |
|---|---|---|
| 正常拍摄 | ⚠️ | 模拟器无相机，用 fixture 注入跑通同一条代码路径；真机需手工验 |
| 拍摄后确认 | ✅ | `testT04`（预览 → 使用这张 → 裁剪） |
| 拍摄后重拍 | ✅ | `testT06` |
| 拍摄后取消 | ✅ | `testT20` |
| 从相册导入 | ✅ | 2026-10-28 真实系统 PhotosPicker 选取/取消→裁剪→确认→取消回列表，截图已留存 |
| 相机权限拒绝 | ✅ | `testT03`（注入 denied）；真实系统权限路径未验、暂缓 |
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
| **竖版** | ✅ | 有竖版**版式**（638×1012，`zh-04` 等），**竖排文字**（日式竖书）是已知限制，PDF 未明确要求，不作为竖版布局缺口 |
| 不同字体 | ✅ | v2 确定性轮换：英文 Arial/Times/Courier，中文与双语 Hiragino/STHeiti/Songti；font_file 存入 GT/manifest |
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
| Structured Fields | ✅ | RecognitionSnapshot 持久化修改前 ParsedCard/evidence |
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
| 字段歧义（如 "Apple" 是公司/产品/地址） | ✅ 测试覆盖 | 新增 Apple 孤立词、姓名后公司候选、地址中同词三个上下文测试：孤立词留在未归类文字；公司候选低置信提示；地址不误作公司。不硬编码品牌词，不代表任意歧义均能消除。 |
| 人名与公司混淆（Jordan Lee / Lee Consulting） | ✅ | `FieldParserTests.testPersonNameIsNotCompany` |
| 多电话判断 Mobile/Office/Fax | ✅ | 标签优先；同号不同显式类型分别保留；无标签仍有格式/低置信回退歧义，按准确率报告计错 |
| 中英文混排 | ✅ | `TextNormalizer.separateScriptRuns` |
| 字段缺失不得凭空产生 | ⚠️ | 已检查完整字段集合并记录误填；无标签号码归类和 OCR 错字仍可能导致误填，不能宣称全部字段为零 |

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
| 保存 → Kill App → 重开 → 找到该名片 | ✅ | 文件完整回读 + 独立文件库 terminate/launch UI 回归；真机仍待验 |
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

本地修复、自动化结果和原审查 R01–R17 的对应关系见 `docs/reports/review-fixes-2026-10-28.md`。不得把功能表打勾解释成真机或行为等价全部签收。

| # | 缺口 | 严重程度 | 建议 |
|---|---|---|---|
| 1 | 正版 CamCard 参考环境与行为/截图对比 | 高，未验 | 锁定版本、设备、语言、登录态并逐条签收 |
| 2 | 真机相机、权限、通讯录与实拍质量 | 高，未验 | 按 external-acceptance 清单录屏、核对字段 |
| 3 | 不支持竖排文字（只有竖版版式） | 中 | Vision 对竖排也弱；建议写进"已知限制"，不作为承诺 |
| 4 | 系统 PhotosPicker 实际选取/取消 | ✅ 已留证 | 模拟器系统选择器手动验证，见审查修复记录 |
| 5 | 可选字段 Postal Code 未单独建模 | 低 | 作业标为可选；邮编已保留在地址字符串中 |

**累计补掉的缺口**（都是"实现有、入口没有"或"逻辑有、坐标算错"）：

0. **拍摄结果预览**：原本没有独立预览页，裁剪页兼任——用户"这张拍糊了"和"边角在哪"两个判断挤在同一屏。现在拆成 `PreviewView`。
1. **方向校正**：EXIF 旋转的照片，检测用带方向的坐标、校正用原始像素 → 会歪。现在入口统一归一。
2. **查看原始名片**：`originalImageID` 一直存着，但详情页没有入口。现在点图片可切「校正图/原图」。
3. **删除标签**：`deleteTag` 早就有，UI 没暴露。现在标签区有「删除标签」菜单。

> 这三条说明一件事：**"作业文档里写了"和"用户点得到"之间还有距离**。审计的价值就在这里——
> 功能表打勾不等于能用。
