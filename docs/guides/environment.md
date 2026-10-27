# 环境搭建（macOS）

## 需要什么

| 组件 | 版本 | 说明 |
|---|---|---|
| macOS | 27.x | 本机 27.0.1 |
| Xcode | 27.1 | 来自公司 Self Service（App Store 也可） |
| iOS SDK | 27.1 | 随 Xcode |
| 模拟器 runtime | iOS 27.1 | `xcodebuild -downloadPlatform iOS`（约 8–10 GB） |
| XcodeGen | 最新 | `brew install xcodegen` |
| Python 3 + Pillow | 3.12+ | 仅重新生成语料时需要 |

## 首次安装

```bash
# 1. 接受许可（需要管理员）
sudo xcodebuild -license accept

# 2. 安装附加组件
sudo xcodebuild -runFirstLaunch

# 3. 下载模拟器 runtime（不需要 sudo，耗时较长）
xcodebuild -downloadPlatform iOS

# 4. 工具
brew install xcodegen swiftlint swiftformat

# 5. 验证
xcodebuild -version && xcrun simctl list runtimes
```

## 生成工程并跑起来

```bash
make bootstrap
make build
open CamCardReplica.xcodeproj    # Cmd+R
```

命令行跑测试：

```bash
make test
make test-ui
```

## 常见问题

| 现象 | 处理 |
|---|---|
| `unable to find utility simctl` | 未装 Xcode 或 `xcode-select` 指向 CLT：`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| `You have not agreed to the Xcode license` | `sudo xcodebuild -license accept` |
| 模拟器列表为空 | 没下载 runtime：`xcodebuild -downloadPlatform iOS` |
| 相机预览黑屏 | 模拟器没有摄像头，属预期；用相册或测试名片 |
| 编译报 `No such module 'Vision'` | 部署目标写成 macOS 了，检查 `project.yml` 的 `platform: iOS` |
| 签名错误 | 模拟器不需要签名；真机需在 Xcode 里选个人 Team |
| `Unable to create a device for device type` | 本机受公司 MDM 管理，**只允许已存在的模拟器**（本机为 `iPhone Duo`）。`Makefile` 的 `DESTINATION` 已按此设置，命令行可用 `DESTINATION='platform=iOS Simulator,name=...'` 覆盖 |
| `Install Failed: Authorization is required` | `xcodebuild -runFirstLaunch` 需要管理员：`sudo xcodebuild -runFirstLaunch` |
