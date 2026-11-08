# 验证与复现记录（2026-11-08）

## 环境与修改范围

macOS 27.0.1、Xcode 27.2、iOS SDK 27.2、iPhone 18 Pro 模拟器 / iOS 27.0；时区 Asia/Shanghai。正版环境为官方 Android CamCard 8.25.0.20260129、Android 15 / API 35 模拟器、Basic 模式、英语与简体中文。

本轮修改正版采集、界面字段读取、比较、打包检查、CI 及提交文档。App 的 Sources、Swift 测试、TestData 与 GT 保持原有内容；同图比较采用 2026-11-07 已归档的 Vision 输出。

## 本地运行结果

| 检查 | 实际结果 | 原始记录 |
|---|---|---|
| make verify | 13:15 和修正读取工具后的 13:48 两次完成，构建成功；109 个单元/集成方法，0 失败 | TestResults/reference-final-verify-after-replay-2026-11-08.log；最新结果包 2026.11.08_13-46-53 |
| make test-evidence | 5 项通过 | Python 检查摘要 |
| make test-reference-evidence | 界面读取 8 项、比较 11 项、打包拒绝条件 3 项通过 | Python 检查摘要 |
| 原有工具检查 | uv 提供 Pillow 和 NumPy 后 3 项通过 | 工具检查摘要 |

make test-tooling 首次使用系统 Python，因缺少 Pillow 退出，未执行测试；随后按既有复现命令运行 3 项检查并通过。make verify 的 Vision 运行仍有 CVPixelBufferCreate -6680 诊断输出，测试成功且全部图片产生输出，相关识别错误照常计入既有统计。

永久摘要保存于 [本轮附件](evidence/validation-reference/README.md)。完整 Xcode 日志与结果包保留在本地 TestResults 和 build/Logs/Test。

## 采集完整性与比较

正式同图条件、版本、逐图选择、完整表单与实际字段见 [正版验证](reference-validation.md)和 [原始证据](evidence/reference-android/README.md)。比较工具核对 76 张固定原图、输入哈希、语言与模式、取消保存标记、截图尺寸及 XML 重算字段；打包工具再次核对原始证据、运行元数据、字段统计和工具源码哈希。

后台进程在完成 58 张后退出，日志没有报错。旧进程结束后取消未完成的 bi-08-occluded.png 表单，再从缺失条目继续，保留已有完整记录。全部首次结果计入统计；空结果复查单独归档。

完成 70 张后模拟器退出，ADB 准备 bi-16.png 时失败；恢复同一 AVD 后核对原有配置和空名片夹，再完成余下 6 张。全部 76 条 record.json 与 discarded.txt 检查通过；两个空结果复查仍为空，最终名片夹为 0 条联系人。

Nickname 地址归类回归先出现一项断言失败，修正读取规则后通过。从原始 XML 重算 25 张解释记录，原始图片和 XML 保持原有内容，旧解释保留。最终比较与哈希清单重新生成。

## 验证范围

本次 make verify 执行单元和集成测试；UI、系统相机授权、FauxCam 与 iPad 使用带日期的历史证据，详见 [2026-11-07 记录](verification-local.md)。本轮没有再次执行完整 UI 或真实设备拍摄。

正版 Android 的导入、保存、取消和测试记录软删除，以及官网录入、详情、编辑、搜索、分组、备注与重新加载分别注明平台。iOS 正版、真实拍摄质量、正版网络与存储异常的完整注入、CamCard 会员导出文件未验证。T18 使用本项目模拟器终止与重新启动证据，T19 使用本项目 VCF 全字段反序列化证据。

TRAE 使用记录归档在 [TRAE 使用记录](../ai-collaboration/trae-record.md)；本人仍需填写作者信息、本人修改案例、验收与演示结果，见 [简明清单](../submission/user-actions.md)。

## 复现命令

```bash
make bootstrap
make verify
make test-evidence test-reference-evidence
uv run --with pillow --with numpy python Scripts/test_tooling.py
python3 Scripts/compare_reference_camcard.py
make audit
git diff --check
make package
```

重新采集需先完成官方应用安装、登录和协议确认，并独占指定模拟器；不要在已运行的采集进程之外同时操作。正常采集命令为 python3 Scripts/collect_reference_android.py，完整前置条件见正版验证记录。

提交包包含 Markdown、相对路径图片与原始证据，以及 START-HERE.md、SUBMISSION.json 和 MANIFEST.sha256。版本与工作区状态以最终打包时的实际 Git 状态记录；工具验证 ZIP CRC 和逐文件 SHA-256。
