# 数据模型

## BusinessCard

持久化格式：`~/Library/Application Support/CamCardReplica/library.json`（JSON，ISO-8601 时间）。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | UUID | ✓ | 主键 |
| `name` | String | ✓ | 姓名；允许为空字符串（脏数据兜底），UI 保存时要求非空 |
| `company` | String? | | 公司；`nil` 表示名片上没有 |
| `jobTitle` | String? | | 职位 |
| `department` | String? | | 部门（可选字段） |
| `phones` | [PhoneNumber] | | 可多个，带 kind |
| `emails` | [String] | | 可多个 |
| `website` | String? | | 网站 |
| `address` | String? | | 地址（可多行合并为一行） |
| `notes` | String? | | 备注 |
| `tags` | [String] | | 标签名（去重、排序） |
| `originalImageID` | String? | | 原图文件名（不含扩展名） |
| `processedImageID` | String? | | 校正图文件名 |
| `rawText` | String? | | OCR 原文（用于错误分析） |
| `recognition` | RecognitionSnapshot? | | 原始 OCR（逐行文本/坐标/置信度）及人工修改前 ParsedCard；旧记录缺此项时为 nil |
| `createdAt` / `updatedAt` | Date | ✓ | 排序依据 |

### PhoneNumber

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | |
| `kind` | `mobile` / `office` / `fax` | 唯一区分多号码的依据（T10） |
| `number` | String | 保留原始格式，不强制归一化（便于比对 Ground Truth） |

### CardTag

| 字段 | 类型 | 说明 |
|---|---|---|
| `name` | String | `id` = 小写 name，保证大小写不重复 |

### 为什么图片不入库

图片以 `<uuid>.jpg` 存于 `Images/`，JSON 只存路径。理由：JSON 可读、可 diff、
删除名片时能精确清理文件，避免 BLOB 导致的迁移与内存问题（ADR-0003）。

## 解析证据与编辑草稿

| 类型 | 用途 |
|---|---|
| `OCRResult` | OCR 原始输出：`lines[]`（文本/坐标/置信度）+ `rawText` + 耗时 |
| `ParsedCard` | 解析结果：8 字段 + `ParsedValue{value, confidence, evidence}` |
| `RecognitionSnapshot` | OCRResult + 原始 ParsedCard，随名片一起 Codable 持久化；人工编辑不改快照 |
| `CardDraft` | 可编辑表单；空串保存为 nil；标签删除暂存 deletedTags，取消丢弃，保存时一次提交 |

## 字段规则（解析器）

| 字段 | 判据 | 典型置信度 |
|---|---|---|
| name | 字号最大且无其它字段特征；去称谓（Dr./教授…） | 0.93 / 0.86 / 0.72 |
| jobTitle | 命中职位词表；排除以机构词结尾的行 | 0.90 |
| company | 命中机构词表且地址特征弱；优先后缀匹配 | 0.90 / 0.78 / 0.62（回退） |
| department | 命中部门词表且不弱于机构词 | 0.78 |
| mobile/office/fax | 每个号码使用最近标签；先排除邮箱/URL 占用区间；无标签仍按既定格式/低置信兜底，不用 GT 推测 | 0.96 / 0.88 / 0.58 |
| email | 正则 | 0.96 |
| website | 网站标签或 www/http(s) 前缀为证据；排除 email 行；裸域名不确定时留在未归类文字；不在 TLD 中途截断 | 0.92 |
| address | 行政/街道/邮编特征加权 + 复合街道后缀（…strasse） | 0.84–0.90 |

置信度 < 0.5 一律 `nil`（宁缺勿造，T09）；< 0.78 在 UI 标记「请确认」。
