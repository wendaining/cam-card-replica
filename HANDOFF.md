# HANDOFF — 提交材料与验证记录

更新日期：2026-11-08。读取 AGENTS.md 后，可直接查看 [提交目录](docs/submission/README.md)和 [最终报告](docs/reports/final-report.md)。

## 本地交付材料

- [最终报告](docs/reports/final-report.md)已补充实现、规格追溯、测试、完整字段统计、错误案例、AI 协作、界面截图和验收状态。
- [OCR 原始证据](docs/reports/evidence/ocr-measurement/README.md)包含 76 条实际记录、识别输入 PNG、原始文字、初始解析、检测四角、运行元数据与文件哈希。
- [AI 协作记录](docs/ai-collaboration/README.md)说明实际使用 Codex 与 TRAE。TRAE 的使用记录归档在 [TRAE 使用记录](docs/ai-collaboration/trae-record.md)。
- [正版同图比较](docs/reports/reference-comparison.md)覆盖 Android Basic 的全部 76 张原图，原始截图、XML 和字段归档在 reference-android。
- [最终填写模板](docs/submission/final-signoff.md)保留作者、真实拍摄限制、正版参考数据、演示与提交说明；参考行为表、参考 OCR 表和人工修改表均已准备。
- 报告以 Markdown 保存，提交压缩包位于 output/submission。

## 当前验证

环境：macOS 27.0.1、Xcode 27.2、iOS SDK 27.2、iPhone 18 Pro / iOS 27.0。

| 检查 | 实际记录 |
|---|---|
| make verify | 2026-11-08，109 个单元/集成方法，0 个非预期失败 |
| make bench | 2026-11-07 的 7 个评测方法通过，76 个图片输入全部产生输出 |
| FauxCam 专项 | 关闭固定图源，正常快门、照片回调、重拍、识别、原文和保存通过；18.967 秒 |
| 系统权限专项 | 四项通过，原生系统弹窗允许与拒绝均有截图；未加载 FauxCam |
| iPhone UI | 2026-11-07，24 个功能方法通过，1 个截图方法默认跳过 |
| Python 工具检查 | 3 项通过 |
| 证据导出检查 | 原有 5 项通过；新增正版界面、比较、打包检查 22 项通过 |
| 正版测量 | 官方 Android 8.25.0.20260129 Basic，76 张完整原图 |
| 文档审计与文件完整性 | 见 [最新验证](docs/reports/verification-reference.md) |

2026-11-08 修改范围为正版采集、比较、证据检查、打包、CI 和文档。App 的 Sources、Swift 测试与语料保持原有内容。iPhone UI、FauxCam 与系统权限使用 2026-11-07 的证据；iPad UI 沿用 2026-10-28 的历史结果，最新 T18 调整未在 iPad 复验。

## 需要使用者填写

模拟器原生系统权限四项检查已经通过，证据见 [权限记录](docs/reports/evidence/permissions/README.md)。使用者没有 iPhone，真实拍摄质量、iOS 正版及会员导出文件未验证。Android 正版同图与网页管理操作已归档；本人修改案例和最终提交信息见最终确认表，TRAE 使用记录见 [TRAE 使用记录](docs/ai-collaboration/trae-record.md)。具体操作与证据名称见 [提交目录](docs/submission/README.md)。

T18 已有模拟器真实终止并重新启动的证据。T19 已有 VCF 完整字段反序列化测试。课程接受这两条证据路径，真机通讯录结果按实际选择补充。

## 工程约束与历史资料

技术栈保持 SwiftUI、Vision、Core Image、纯规则解析和 Codable JSON/图片存储。所有写入通过 CardLibraryModel 提交，识别候选经人工确认后保存。语料 v2 保持 50 张合成名片、76 张图片及原有 GT。

原审查报告和修复记录保留日期、基线与测试结果。概率性测量按字段统计；无标签电话类型的既有歧义继续计错，期望失败保留在测试中。

PR #1 于 2026-10-28 合并到 main，合并提交为 058fa4108fc86a7b3df26a2e39fa746f03ee8c82。本项目 Vision 测量以 77a8bf8 为 Git 基线，实际识别代码内容由 run.json 的源文件哈希确定。后续工作分批提交至 main，最终文件版本由提交包清单记录。

## CI 与复现

远端 CI 当前执行 Linux 文档审计与证据工具检查；Xcode 构建、单元/集成和 UI 是本地检查。历史 macOS CI 使用 Xcode 16 / iOS 17 时发现导航按钮与滚动定位脆弱性，相关测试已修改，T18 的最后调整仅在本地 iOS 27 验证。

```bash
make bootstrap
make verify
make bench
make test-evidence test-reference-evidence
make audit
make package
```

OCR 导出需要实际日期、环境、结果包与证据目录参数，命令见 [验证记录](docs/reports/verification-local.md)。修改报告后重新生成压缩包。
