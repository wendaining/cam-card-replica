# 测试策略

## 确定性行为

单元测试覆盖解析反例、仓库提交/失败回滚、图片一致性、标签草稿、导出及识别快照兼容。UI 覆盖扫描、保存、原图切换、编辑、搜索、删除确认、取消、失败与空字段。T18 使用独立 UUID 文件库真正 terminate/launch，不把重建内存模型当成进程重启。

20条验收定义见 acceptance，方法数不是覆盖率。真机/正版未验项单列在 external-acceptance；不得用模拟器绿灯冒充签收。

## 三类识别指标

1. 保留理想 GT 文本首值历史门槛。只说明文本到字段，不说明 Vision 或图片质量。
2. 理想文本完整集合：所有号码/邮箱、缺失字段、漏值、多值。无标签传真/座机歧义显式标为预期失败，仍计错；不能据缺网站检查宣称全部字段误填率为零。
3. ImageCorpusTests 对全部76张图真实检测/校正/OCR/解析，与 GT 比较全部字段；每图明细附入 xcresult。报告包括全图片、已印字段、缺失误填率和漏/多值，保留语言/字体/版式/标签/图像种类维度。不为 Vision 读错增加语料专用修补，也不降低原文本门槛。

比较忽略大小写/首尾空白；空字符串和 nil 均表示缺失；电话号码内部格式保留。完整集合计分器有漏第二邮箱、多号码、缺失误填的回归反例。

## 语料 v2

50张合成名片/76张图：50 flat、12 photo、10 occluded、4 occluded-photo。业务字段 GT 与 v1 相同；字体分配变化，图像结果不可与 v1 直接作差。

英文按编号选择 Arial/Times New Roman/Courier New，中文/双语选择 Hiragino Sans GB/STHeiti/Songti。指定字体不存在直接报错；font_file 存入 GT 和 manifest。固定 seed=20261027，固定发布时间，生成器同步九个 app fixture。

Pillow 与 NumPy 是生成器依赖，不是 App 的 SPM 依赖。可通过 make testdata PYTHON=解释器路径重建；make test-tooling 验证字体选择和构建路径。本次重复生成所有图片、GT、manifest、fixture 逐文件 SHA-256 一致，业务 GT 与原版本逐项相等。

## 命令与证据

- make verify：阻塞式 swiftlint、build、全部单元/集成；swiftformat 仅报告。
- make test-ui、make test-ipad：真实交互回归，逐个模拟器串行执行。
- UI 目标不收集代码覆盖率，避免当前 Xcode 在 UI 用例结束后等待覆盖率回收；单元/集成仍按工程配置收集，功能断言未跳过。
- make bench：保留文本基准并测量真实全部图片；pipefail 确保测试失败不被 tee 掩盖。
- python3 Scripts/report_benchmark.py：从 bench 日志生成完整 JSON 与图像准确率表。
- make audit：校验当前文档引用和数字；修复前审查快照按历史文档处理。场景数取验收定义，不从 UI 方法数量推算。

最新运行结果见 `docs/reports/review-fixes-2026-10-28.md`。CI 的 UI 步骤现为必过，不再 continue-on-error。远端 CI 结果须另查，不能推断为本地已跑结果。
