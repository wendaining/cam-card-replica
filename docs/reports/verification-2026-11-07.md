# 验证与复现记录（2026-11-07）

## 环境与修改范围

macOS 27.0.1；Xcode 27.2（27B52）；iOS SDK 27.2；iPhone 18 Pro 模拟器、iOS 27.0。日期与时区采用 Asia/Shanghai。

本次修改 ImageCorpusTests、报告导出、证据校验、打包工具和文档。App 的 Sources 目录仅更新相机权限测试边界注释，运行逻辑保持原有实现，语料与 GT 保持原有内容。

## 实际运行结果

| 检查 | 实际结果 | 结果包或附件 |
|---|---|---|
| 证据测试修改前 | 1 个方法出现 6 项断言失败 | 永久测试摘要 |
| 证据测试修改后 | 同一方法通过，0 失败 | 2026.11.07_20-44-11 |
| make verify | 109 个单元/集成方法，0 个非预期失败；构建成功 | 2026.11.07_20-46-03 |
| make bench | 7 个评测方法通过，0 个非预期失败 | 2026.11.07_20-47-36 |
| iPhone 完整 UI | 24 个功能方法通过；1 个截图方法默认跳过 | 2026.11.07_20-18-10 |
| FauxCam 正常快门专项 | 1 个方法通过，18.967 秒；fixture-camera=NO | 2026.11.07_23-01-23 |
| make test-evidence | 5 项通过 | python-evidence.txt |
| Python 工具检查 | 3 项通过 | python-tooling.txt |
| OCR 导出 | 76 条识别记录与 76 张实际输入 PNG 校验通过 | OCR 证据目录及运行元数据 |
| 文档与文件检查 | make audit、git diff --check 通过 | 本地终端输出与提交清单 |

[永久测试摘要](evidence/validation-2026-11-07/verification.txt)、[Python 证据检查](evidence/validation-2026-11-07/python-evidence.txt)、[Python 工具检查](evidence/validation-2026-11-07/python-tooling.txt)随提交材料保存。

完整 Xcode 日志保留在本地 TestResults，结果包保留在 build/Logs/Test。提交材料保存必要摘要、可复现代码、运行元数据和识别附件。iPad 沿用 2026-10-28 的历史 UI 结果；正常快门与照片回调已通过 FauxCam 专项；原生系统权限已在模拟器完成四项专项；实拍质量、正版行为与同图识别保留未验证状态。

## OCR 证据导出

```bash
make bootstrap
make verify
make bench
python3 Scripts/report_benchmark.py \
  --log TestResults/permission-final-verify-2026-11-07.log \
  --date 2026-11-07 \
  --environment 'Xcode 27.2 / iPhone 18 Pro / iOS 27.0' \
  --xcresult 'build/Logs/Test/Test-CamCardReplica-2026.11.07_23-54-46-+0800.xcresult' \
  --evidence-dir docs/reports/evidence/ocr-2026-11-07
make test-evidence
```

以上导出参数对应 23:55 完成的完整验证运行，该次日志同时包含全部 76 个输入的测量。普通 make bench 将日志保存为 TestResults/bench.log；重新测量时填写该次日志、日期、设备环境与结果包路径。

结果包路径由 xcodebuild 结束时输出。导出工具要求测试运行成功，识别记录完整，并检查原图、处理图片、GT 及初始字段比较。所有哈希均可用 Python hashlib 或系统 shasum 复算。

每张输入保留 Vision 第一候选文字、位置、置信度、识别语言、尺寸与耗时。检测四角按左上、右上、右下、左下记录。图片 SHA-256 对应实际导出的 PNG 字节。

## 文档与提交文件

```bash
python3 Scripts/test_report_evidence.py
uv run --with pillow --with numpy python Scripts/test_tooling.py
make audit
git diff --check
make package
```

最终报告保存在 docs/reports/final-report.md，提交压缩包直接包含 Markdown 正文、相对路径图片与附件。

压缩包包含 MANIFEST.sha256、SUBMISSION.json 和 START-HERE.md；打包工具检查 ZIP CRC、逐文件 SHA-256、OCR 证据哈希及测量时源码哈希。作者填写模板后更新 Markdown 报告并执行 make package。

## 诊断记录

首次检查遇到 CoreSimulator 1174.9.2 与 Xcode 要求的 1174.21.0 不匹配。系统组件更新后设备恢复可用，后续构建与测试完成。

Vision 在部分输入输出 CVPixelBufferCreate -6680 诊断日志，本次所有图片仍产生 OCR 结果，相关文字及字段纳入统计。已知无标签号码类型歧义保留期望失败与错误计数。确定性验收状态以逐项证据和作者实际观察记录。

FauxCam 使用 make test-fauxcam 显式运行，安装位置、配置和结果见 [相机专项](fauxcam-validation-2026-11-07.md)。

提交前再次执行 make verify，2026-11-07 23:04 完成，109 个方法通过，0 个非预期失败；结果包为 2026.11.07_23-03-14。FauxCam 专项在 23:01 的独立结果包通过，新增系统权限专项后 UI 定义总数为 27。

系统相机权限专项在 23:50–23:51 完成四项独立运行：已有授权 9.411 秒、已有拒绝 8.403 秒、系统弹窗允许 10.232 秒、系统弹窗拒绝 10.193 秒，全部通过。使用真实 SystemCameraPermission，未注入 FauxCam，见 [原始证据](evidence/permissions-2026-11-07/README.md)。

权限测试和注释更新后再次执行 make verify，23:55 完成，109 个方法通过，0 个非预期失败，结果包为 2026.11.07_23-54-46。从该次实际结果重新导出 OCR 原始证据，76 条逐字段比较与此前归档完全一致，测量元数据保存当前源码哈希。
