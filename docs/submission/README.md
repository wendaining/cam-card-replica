# 提交材料目录

| 阅读材料 | 内容 |
|---|---|
| [最终报告](../reports/final-report.md) | 实现、规格追溯、测试、OCR 测量、错误分析、能力限制与当前验收状态 |
| [最终填写模板](final-signoff.md) | 作者信息、实际提交日期、参考 App 数据与未验证内容 |
| [本人操作清单](user-actions.md) | 提交信息与本人修改记录 |
| [参考环境表](reference-environment.md) | CamCard 版本、设备、系统、语言、登录状态和功能范围 |
| [参考行为记录](reference-observations.csv) | T01–T20 已观察的平台、结果与限制 |
| [参考 OCR 记录](reference-ocr.csv) | 76 个图片条目，包含 GT、本项目与正版 Android 初始字段 |
| [正版同图报告](../reports/reference-comparison-2026-11-08.md) | 76 张完整字段、误填、漏值、多值与 F1 |
| [正版原始证据](../reports/evidence/reference-2026-11-08/README.md) | 逐张选择、完整表单截图、XML、字段与哈希 |
| [人工修改记录](manual-corrections.csv) | 修改前后字段、操作者、日期和证据 |
| [AI 协作记录](../ai-collaboration/README.md) | Codex 过程记录与 TRAE 使用记录 |
| [OCR 原始证据](../reports/evidence/ocr-2026-11-07/README.md) | 原文、初始解析、识别输入、逐行置信度及 SHA-256 |
| [系统相机权限](../reports/evidence/permissions-2026-11-07/README.md) | 系统授权四项、实际弹窗与 API 探测 |
| [FauxCam 专项](../reports/fauxcam-validation-2026-11-07.md) | 正常快门、照片回调、重拍和识别保存的实际截图与记录 |
| [最新验证](../reports/verification-2026-11-08.md) | 正版采集、109 项回归和证据检查 |
| [验证记录](../reports/verification-2026-11-07.md) | 命令、时间、实测结果、测试范围和证据附件 |
| [验收追溯](../spec/acceptance.md) | T01–T20 对应规格、测试与代码 |

## 文件使用

最终报告使用 Markdown，可直接编辑。作者信息、实际修改案例与演示结果按实际填写；每次修改验收结果时填写日期和证据路径。

提交压缩包包括源码、工程生成配置、规格与测试文档、语料、OCR 证据、报告和填写模板。压缩包附带逐文件 SHA-256 清单及版本信息。build、DerivedData、TestResults、Git 内部文件和本机环境文件不在压缩包中。

## 更新提交压缩包

在项目根目录运行 `make audit` 与 `make package`。生成文件位于 output/submission。修改报告后执行打包命令。完整复现命令见 [验证记录](../reports/verification-2026-11-07.md)。

## 提供资料的方式

正版 Android Basic 同图比较已经覆盖全部 76 张图片。TRAE 使用记录已经归档在 [TRAE 使用记录](../ai-collaboration/trae-record.md)；作者可以直接补充本人修改案例及最终提交信息，本人操作要求见简明清单。物理拍摄质量、iOS 正版和会员导出文件明确保留未验证状态。
