# 系统相机权限原始证据

日期：2026-11-07，Asia/Shanghai。Xcode 27.2 / iPhone 18 Pro 模拟器 / iOS 27.0。

使用 SystemCameraPermission，未配置 FauxCam 动态库或固定权限服务。四项界面测试均通过，授权与拒绝分别检查快门可用状态及拒绝说明。

| 条件 | 设置或操作 | 实际结果 | 耗时 |
|---|---|---|---|
| 已有授权 | simctl privacy grant camera | 快门可用，无拒绝说明 | 9.411 秒 |
| 已有拒绝 | simctl privacy revoke camera | 快门禁用，显示拒绝说明 | 8.403 秒 |
| 首次允许 | reset camera 后选择系统弹窗“允许” | 快门可用，无拒绝说明 | 10.232 秒 |
| 首次拒绝 | reset camera 后选择系统弹窗“不允许” | 快门禁用，显示拒绝说明 | 10.193 秒 |

系统弹窗实际文字为“允许‘CamCard Replica’访问相机？”，按钮为“不允许”和“允许”。prompt-prompt-allow.png 与 prompt-prompt-deny.png 保存操作前的系统弹窗，其他四张图片保存操作后的界面。

grant-api.txt、deny-api.txt 与 system-camera-probe.swift.txt 保留独立 AVFoundation API 探测：授权状态分别为 authorized 与 denied，requestAccess 返回值分别为 true 与 false；设备发现返回无后置设备，DYLD_INSERT_LIBRARIES 未设置。simctl-camera.txt 为空，表示授权命令正常完成且无输出。

复现命令：make bootstrap，然后执行 make test-camera-permissions。脚本仅修改本应用的模拟器相机授权，结束时移除专项配置并恢复允许状态。完整日志保留在本地 TestResults，各场景摘要随本目录提交。

本项验证系统授权流程。真实摄像头、光照、反光、对焦、实际设备上的设置返回均未验证。使用者没有 iPhone，提交说明保留该设备限制。
