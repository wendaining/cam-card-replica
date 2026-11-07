# FauxCam 相机流程验证（2026-11-07）

## 工具与安装

来源：[FauxCam 官方项目](https://github.com/mkemalgokce/fauxcam)及 [v1.1.0 发布](https://github.com/mkemalgokce/fauxcam/releases/tag/v1.1.0)。应用与 CLI 均使用 1.1.0。

- 应用：`~/Applications/FauxCam.app`。
- CLI：`~/.local/bin/faux`。
- 发行 DMG SHA-256：95e4adbc65a5fd7b6eeb9c44424f267c47e9d3c3ec52c47971830cb2fb91fc86。
- CLI SHA-256：f8bb32a2edb7757bec066a125956ced0fca9478b33bdc4bb2575339e7309b3d6。

两个下载与 GitHub 发布资产的哈希一致，应用通过 Developer ID 公证检查。专项从应用资源复制 libFaux.dylib 到用户缓存，对副本执行本地 ad-hoc 签名，并使用 faux doctor 检查；原始安装应用保持其发行签名。

## 实际运行条件

| 项目 | 条件 |
|---|---|
| 开发环境 | Xcode 27.2 / macOS 27.0.1 |
| 设备 | iPhone 18 Pro 模拟器 / iOS 27.0 |
| 输入 | TestData/cards/en-01.png |
| 图像帧 | 720×1280，15 fps，竖向输出 |
| 注入范围 | 本次启动的 CamCardReplica 测试进程 |
| App 图源配置 | fixture-camera=NO |
| 权限服务 | SystemCameraPermission，视频授权结果由 FauxCam 提供 |
| 存储 | 独立内存库 |
| 结果 | 1 个方法通过，0 失败，18.967 秒 |
| 结果包时间 | 2026.11.07_23-01-23，Asia/Shanghai |

使用 `FauxCameraUITests.testT04_fauxCameraShutterRetakeRecognizeAndSave` 检查：进入扫描、快门可用、固定测试按钮缺席、正常拍摄、照片预览、重拍、再次拍摄、四角裁剪、Vision 识别、姓名 David Chen、OCR 原文显示和保存后列表记录。

首次使用横向 1280×720 帧时，竖屏取景出现放大裁切；照片回调与识别流程通过。专项配置随后使用竖向帧，重新执行通过，本页截图和元数据对应最终竖向运行。

## 截图与记录

| 操作 | 附件 |
|---|---|
| 扫描与正常快门 | [01-camera.png](evidence/fauxcam-2026-11-07/01-camera.png) |
| 照片预览 | [02-preview.png](evidence/fauxcam-2026-11-07/02-preview.png) |
| 四角裁剪 | [03-crop.png](evidence/fauxcam-2026-11-07/03-crop.png) |
| 实际识别表单 | [04-review.png](evidence/fauxcam-2026-11-07/04-review.png) |
| OCR 原文 | [05-raw-text.png](evidence/fauxcam-2026-11-07/05-raw-text.png) |
| 保存结果 | [06-saved.png](evidence/fauxcam-2026-11-07/06-saved.png) |

[运行元数据](evidence/fauxcam-2026-11-07/run.json)、[测试摘要](evidence/fauxcam-2026-11-07/verification.txt)和 [文件哈希](evidence/fauxcam-2026-11-07/SHA256SUMS.json)同时归档。

## 复现

安装 FauxCam 应用及 CLI 后，在项目根目录执行 `make bootstrap` 和 `make test-fauxcam`。工具位于其他位置时，可以设置 FAUX_APP 与 FAUX_CLI。脚本负责帧服务、测试配置、运行及清理，日志保存在 TestResults/faux-camera-latest.log。

专项通过 XCTest 的 launchEnvironment 向目标进程传递动态库路径与帧服务 socket，使用现有正常快门入口。测试结束后终止测试 App，停止帧服务并清理启用配置。常规 UI 测试在没有专项配置时跳过此方法。

FauxCam 对视频授权返回 authorized。真实系统弹窗、拒绝权限与从设置返回仍需实际设备记录。光照、反光、模糊和对焦等拍摄质量保留待测量状态。
