# 正版 CamCard 验证与同图采集（2026-11-08）

## 应用与设备

| 项目 | 实际记录 |
|---|---|
| 下载入口 | [CamCard 官方下载页](https://www.camcard.com/site/download) |
| Android 安装包 | 官方页面提供的 MingPian_CC.apk，147,947,432 字节 |
| 包名 | com.intsig.BizCardReader |
| 实际安装版本 | 8.25.0.20260129，versionCode 82500 |
| 安装包 SHA-256 | 5d1c69289913ed0a0224c481f0f5896adf3fd0dec3b6ade114e1a2bc29cf8caa |
| 签名证书主体 | IntSig / IntSig Information Co.,Ltd / www.intsig.com / Shanghai |
| 测试设备 | Apple M4 Pro Mac 上的 Android Emulator 37.2.13.0 |
| 系统与架构 | Android 15，API 35，AOSP，arm64-v8a |
| 应用界面语言 | 英语；部分产品页面显示中文 |
| 识别语言 | English、Simplified Chinese，同时启用 |
| 识别模式 | Basic |
| 显示配置 | 720×1824，密度 320 dpi |
| 登录与协议 | 使用者完成账号登录，并明确同意首次启动协议 |
| 实际摄像头 | 模拟器内置彩色图源；Mac 摄像头保持未连接 |
| 输入语料 | 原有 50 张合成名片、76 张图片 |

安装、设备、输入与签名证据见 [原始附件](evidence/reference-2026-11-08/)。系统 MediaStore 中的输入图片与仓库逐项核对 SHA-256，76 个原始文件的字节一致。

Mac App Store 显示官方 iPad 应用支持 Apple 芯片 Mac；本机获取流程未完成，日志记录 Anisette 认证错误 -45061。实际同图测量采用表格列明的 Android 安装版本。

## 逐图采集条件

识别前将五条本次生成的测试名片移入回收站，确认页面说明可在 30 天内恢复。正式采集期间，当前名片夹保持为空。每张图片读取完成后，通过返回和 Retake 取消保存。

CamCardReferenceCurrent 相册每次只保留一张待测图片。采集工具核对系统相册条目、文件名称及文件 SHA-256，确认页面中只有一个可选图片控件，随后进行识别。选择状态和确认页面分别保存截图与 XML。

确认页面按固定步长滚动，读取姓名、全部电话、全部邮箱、组织字段、网站和地址组件。每个字段控件通过其完整结构位置关联到同一条记录，重叠区域的字段值必须一致。采集必须同时覆盖姓名控件与表单末尾的 Improve recognition 控件。

collectionSeconds 记录导入、界面等待、滚动和截图的总时长。识别字段在保存前采集，保留全部号码、邮箱与组织字段值。每份记录注明模式、识别语言、时间、输入哈希和完整采集状态。

## 字段读取规则

| 确认页面内容 | 记录方式 |
|---|---|
| 姓名 | et_display_name 的实际内容 |
| 电话 | 保留类型标签及原始号码；Mobile 对应手机，Work 对应座机，Fax 类型对应传真 |
| 无法对应课程类型的电话 | 保存在 unmappedFields，继续保留原始类型与号码 |
| 邮箱、网站 | 收集对应区段的全部实际值 |
| 公司、部门、职位 | 按界面字段逐项保留，多组组织信息继续保留全部值 |
| 空字段提示 | Company、Department、JobTitle 等界面提示文字记录为占位内容 |
| 地址 | 原始组件逐项保留，地址字符串按确认页面组件顺序连接 |
| Nickname | 单独保留为额外控件值，结束地址区段；不并入地址 |
| 滚动重叠内容 | 通过控件结构位置合并；内容冲突时终止采集 |

采集工具的检查包含真实邮箱误识别、多部门结果、电话分类、地址组件、重复快照、缺失页面及滚动过程中内容变化。工具测试见 Scripts/test_reference_camcard_ui.py。

## 官网实际操作

| 操作 | 实际结果 | 证据 |
|---|---|---|
| 登录后首次查看 | 名片夹为空 | web-image-upload.txt 中的空列表计数 |
| 上传 en-01.png | 图片显示在正面区域，姓名、公司等字段保持空白 | web-image-upload.png、web-image-upload.txt |
| 查看导入工具 | 显示 Outlook、LinkedIn、Excel 联系人导入入口 | web-import-options.png、web-import-options.txt |
| 填写字段并保存 | 合成联系人出现在列表 | web-manual-saved.png |
| 查看详情 | 显示录入的电话、邮箱、部门、职位和地址 | web-manual-detail.png、web-manual-detail.txt |
| 编辑姓名与公司 | 修改后重新加载仍可见 | web-edit-reload.png、web-edit-reload.txt |
| 姓名搜索 | David Chen 返回一条测试记录 | web-search-name.png |
| 公司搜索 | ABC Technologies 返回一条测试记录 | web-search-company.png、web-search-company.txt |
| 无匹配搜索 | ZZZ-NO-MATCH-20261108 返回零条 | web-search-empty.png、web-search-empty.txt |
| 分组与备注 | 新建分组、加入名片、按组查看并保存备注；重新加载后仍可见 | web-group-filter.png、web-group-note-reload.png |

上述字段来自自动化操作者的明确输入。网页流程材料用于记录联系人管理行为。逐图 OCR 统计使用 Android 确认页面中的实际识别结果。

## Android 功能观察与限制

相册选取、确认页面、初始字段读取、保存提示、继续扫描、取消当前识别及回收站删除均已实际操作。临时保存的记录用于验证正常流程，正式 OCR 采集保持独立输入条件。

批量导出提供名片图片、Excel 与 vCard 入口。选择 vCard 后进入 Upgrade to VIP 页面，本次没有进行订阅或支付。CamCard 的完整 OCR 原文未在当前确认页面显示，本次保存界面中的结构化结果、地址组件及截图。

iOS 正版界面、真实摄像头拍摄质量和付费功能保留未验证状态。Android 与网页的实际行为在记录中分别注明平台。教师没有提供指定参考版本。

## 最终采集与复查

全部 76 张首次记录和取消保存标记完整。进程在 58 张后退出，随后恢复；70 张后模拟器进程退出，ADB 在准备 bi-16.png 时失败。恢复同一 AVD 后，登录、720×1824 显示配置与空名片夹保留，再继续剩余 6 张。过程见 [采集日志](evidence/reference-2026-11-08/collection.log)。

zh-03.png 与 zh-09-photo-occluded.jpg 的首次结果为空，独立复查仍为空，见 [复查摘要](evidence/reference-2026-11-08/empty-recheck-summary.json)。首次记录继续计入统计。最终名片夹为 0 条联系人，见 [截图](evidence/reference-2026-11-08/empty-reference-library-final.png)与 [检查记录](evidence/reference-2026-11-08/final-library-check.json)。

核对表单发现读取工具曾将 Nickname 控件并入地址。真实 XML 回归测试先失败，修正区段与地址控件规则后通过；从原始 XML 重算 25 张记录，保留旧解释，见 [重算记录](evidence/reference-2026-11-08/interpretation-replay.json)。原始 XML、截图与输入图片保持原有内容。最终统计采用修正后的读取结果。

部分照片变体在正版确认页预览中呈蓝紫色，设备原图哈希仍一致；内部图像处理及颜色变化原因未验证。该次实际输出继续计分。安装、管理与完整表单附件已检查，联系方式来自合成输入或实际 OCR 错字，附件未包含账号登录资料。

## 复现命令

使用者完成官方应用安装、登录、首次启动协议确认，并在识别语言设置中启用英语与简体中文。模拟器中的相机为合成图源，图片权限用于已导入的固定测试图片。

```bash
python3 Scripts/test_reference_camcard_ui.py
python3 Scripts/collect_reference_android.py
```

采集工具只操作指定模拟器中的官方应用界面、系统相册与本次创建的单图相册。遇到未知页面、语言变化、图片哈希不符、字段内容变化或表单采集不完整时停止，并保留已经完成的原始记录。
