# HANDOFF — 提交材料与验证记录

更新日期：2026-11-07。读取 AGENTS.md 后，可直接查看 [提交目录](docs/submission/README.md)、[最终报告](docs/reports/final-report.md)和 [本人操作清单](docs/submission/user-actions.md)。

## 本地交付材料

- [最终报告](docs/reports/final-report.md)已补充实现、规格追溯、测试、完整字段统计、错误案例、AI 协作、界面截图和验收状态。
- [OCR 原始证据](docs/reports/evidence/ocr-2026-11-07/README.md)包含 76 条实际记录、识别输入 PNG、原始文字、初始解析、检测四角、运行元数据与文件哈希。
- [AI 协作记录](docs/ai-collaboration/README.md)说明实际使用 Codex 与 TRAE。使用者确认大量使用 TRAE，具体任务和附件保留填写表格。
- [最终填写模板](docs/submission/final-signoff.md)保留作者、真机、正版参考数据、演示与提交说明；参考行为表、参考 OCR 表和人工修改表均已准备。
- 报告以 Markdown 保存，带哈希清单的提交压缩包位于 output/submission。

## 当前验证

环境：macOS 27.0.1、Xcode 27.2、iOS SDK 27.2、iPhone 18 Pro / iOS 27.0。

| 检查 | 实际记录 |
|---|---|
| make verify | 2026-11-07，109 个单元/集成方法，0 个非预期失败 |
| make bench | 同日 7 个评测方法通过，76 个图片输入全部产生输出 |
| FauxCam 专项 | 关闭固定图源，正常快门、照片回调、重拍、识别、原文和保存通过；18.967 秒 |
| iPhone UI | 同日 24 个功能方法通过，1 个截图方法默认跳过 |
| Python 工具检查 | 3 项通过 |
| 证据导出检查 | 5 项通过 |
| 文档审计与文件完整性 | 见 [验证记录](docs/reports/verification-2026-11-07.md) |

本次修改范围为测试、证据导出和文档，App 的 Sources 保持原有实现。iPhone 完整 UI 使用同日原始检查的运行结果。iPad UI 沿用 2026-10-28 的历史结果，旧系统环境的 T18 修订尚待复验。

## 需要使用者填写

真实系统权限、实拍质量、指定版本 CamCard 页面与行为、同图识别、人工修改次数、TRAE 历史任务附件和最终提交说明保留待验证或待填写状态。具体操作与证据名称见 [本人清单](docs/submission/user-actions.md)。

T18 已有模拟器真实终止并重新启动的证据。T19 已有 VCF 完整字段反序列化测试。课程接受这两条证据路径，真机通讯录结果按实际选择补充。

## 工程约束与历史资料

技术栈保持 SwiftUI、Vision、Core Image、纯规则解析和 Codable JSON/图片存储。所有写入通过 CardLibraryModel 提交，识别候选经人工确认后保存。语料 v2 保持 50 张合成名片、76 张图片及原有 GT。

原审查报告和修复记录保留日期、基线与测试结果。概率性测量按字段统计；无标签电话类型的既有歧义继续计错，期望失败保留在测试中。

PR #1 于 2026-10-28 合并到 main，合并提交为 058fa4108fc86a7b3df26a2e39fa746f03ee8c82。本批 OCR 测量以 77a8bf8 为 Git 基线，实际识别代码内容由 run.json 的源文件哈希确定。后续工作分批提交至 main，最终文件版本由提交包清单记录。

## CI 与复现

远端 CI 当前执行 Linux 文档审计；Xcode 构建、单元/集成和 UI 是本地检查。历史 macOS CI 使用 Xcode 16 / iOS 17 时发现导航按钮与滚动定位脆弱性，相关测试已修改，T18 的最后调整仅在本地 iOS 27 验证。

```bash
make bootstrap
make verify
make bench
make test-evidence
make audit
make package
```

OCR 导出需要实际日期、环境、结果包与证据目录参数，命令见 [验证记录](docs/reports/verification-2026-11-07.md)。作者填写结果后更新 Markdown 报告，并重新生成压缩包。
