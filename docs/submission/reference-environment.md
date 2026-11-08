# 参考环境记录

| 项目 | 实际记录 |
|---|---|
| 观察与操作 | Codex 使用 ADB 自动采集；使用者完成登录及协议确认 |
| 日期和时区 | 2026-11-08，Asia/Shanghai |
| CamCard 版本与构建号 | Android 8.25.0.20260129，versionCode 82500 |
| 包名 | com.intsig.BizCardReader |
| 下载渠道 | CamCard 官方下载页提供的 MingPian_CC.apk |
| 设备 | Apple M4 Pro Mac 上的 Android Emulator 37.2.13.0 |
| 系统 | Android 15 / API 35 / AOSP / arm64-v8a |
| 界面与识别语言 | 英语界面；英语、简体中文同时识别 |
| 显示配置 | 720×1824，320 dpi |
| 登录与协议 | 使用者完成登录；使用者明确同意首次启动协议 |
| 测量模式 | Basic；76 张图片的保存前初始字段 |
| 数据隔离 | 正式采集期间当前名片夹为空；每次取消保存 |
| 免费功能与限制 | Basic 相册识别可用；vCard 导出进入 Upgrade to VIP，未购买 |
| 教师指定参考版本 | 未提供 |
| 教师指定测试集 | 未提供；使用项目固定合成语料 v2 |
| 统一输入 | 50 张名片、76 张图片；原始文件和设备文件 SHA-256 一致 |
| 本项目识别运行 | docs/reports/evidence/ocr-2026-11-07/run.json |
| 比较元数据 | docs/reports/evidence/reference-2026-11-08/comparison-run.json |
| 官网范围 | 登录后验证录入、详情、编辑、搜索、分组、备注及重新加载 |
| iOS 正版 | Mac App Store 获取未完成，记录 Anisette -45061；未验证 |

[安装与操作记录](../reports/reference-validation-2026-11-08.md)保存版本、安装包哈希和流程；[原始证据](../reports/evidence/reference-2026-11-08/README.md)保存逐图截图、XML 和字段。最终工程提交标识记录在压缩包 SUBMISSION.json 中。
