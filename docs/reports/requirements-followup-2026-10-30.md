# 要求补充与验证记录（2026-10-30）

## 本轮完成

- 官网首页和 iPhone 官方帮助页调研，附 URL、摘录、历史版本限制；完成核心功能对比及 UI/交互/状态/数据/异常/工作流证据表。见 [对比文档](difference-analysis.md)。
- 整理 PDF 第十七节 T01–T20，区分原始课程用例、本地执行计划与黑盒观察。见 [参考测试套件](../testing/reference-test-suite.md)。
- 新增三个 Apple 上下文歧义用例；现有规则直接通过，没有修改解析器或合成语料。
- 预留 [AI 协作记录](../ai-collaboration/README.md)，截图和使用情况由使用者按真实过程补充。
- 同步交接和验收文档：人工验收暂缓，T18 使用模拟器证据，T19 使用自动映射与 VCF 回读证据。

## 实际验证

环境：Xcode 27.1，iPhone 18 Pro 模拟器，iOS 27.0。

| 验证 | 实跑结果 | 边界 |
|---|---|---|
| make verify | 成功；108 个单元/集成测试方法，0 个非预期失败 | 既有概率性期望失败仍按原报告解释；本轮未重跑完整 UI 套件 |
| CameraPermissionTests | 4 个方法通过 | 授权/拒绝 stub、仅 authorized 可用相机、系统状态映射；不是系统弹窗自动验收 |
| CardFlowUITests.testT03_cameraDeniedShowsExplanation | 1 个方法通过；0 失败 | 注入 denied，断言权限说明和禁用快门 |
| make audit | 通过 | 路径、测试引用、数量与命令一致性 |

本地结果包位于 build/Logs/Test/，本次 verify 时间戳为 2026.10.30_22-25-30，权限 UI 为 2026.10.30_22-29-06。该目录是可清理构建产物，不作为永久提交附件；摘要摘录见 [验证输出](evidence/official-2026-10-30/verification.txt)。

设备检查使用 xcrun xctrace list devices，仅发现主机和模拟器，没有可供本轮运行的 iPhone/iPad 真机。未改变用户设备权限、未执行实际联系人写入。真实系统相机允许/拒绝、拍摄及其他人工验收按要求暂缓，不计为已通过。
