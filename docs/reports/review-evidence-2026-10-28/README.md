# 审查复现证据

基线提交：`7c938f5`。本目录是修复前的历史快照；当时生产源码与语料未改。以下探针仅在该基线运行，不能对修复后的 throwing API 直接编译；当前行为由正式回归套件验证。

[命令验证汇总](verification.txt) 记录正式套件结果；[手动导出复核](stale-export.txt) 记录编辑后 VCF 未更新的实际观察。

## 故障与解析探针

- [源码](Probe.swift)：直接编译仓库原类型，模拟 save 失败、删除写入失败、标签大小写，以及解析/检测参数反例。
- [输出](probe-output.txt)：macOS 原生运行的结果。检测参数的静默处理属于当前 macOS Vision 观察，API 的合法范围以 Apple 文档为准。

在仓库根目录执行：

```bash
swiftc -parse-as-library Sources/Models/*.swift Sources/Persistence/*.swift \
  Sources/Services/Parsing/*.swift Sources/Services/Recognition/*.swift \
  Sources/Services/Imaging/*.swift Sources/Services/Export/*.swift \
  Sources/App/AppServices.swift Sources/Support/DemoData.swift \
  Sources/Support/FixtureProvider.swift Sources/Support/UITestConfiguration.swift \
  Sources/Features/Scanner/ScanFlowModel.swift \
  docs/reports/review-evidence-2026-10-28/Probe.swift -o /tmp/camcard-review-probe
/tmp/camcard-review-probe
```

探针仅在新建临时目录写合成记录，不操作用户真实联系人或现有名片库。Swift 5 模式编译 Contacts 的 Sendable 警告与本次功能结论无关。

## iOS 全图片链路

- [临时 XCTest 源码](ImageCorpusProbeTests.swift)：只收集比较结果，不新增准确率门槛。源码保留原运行机器的绝对路径；换机器需修改 GT 与图片目录路径。
- [iOS 输出](image-corpus-ios.txt)：先列每组统计，后列所有不一致项。

在独立验证窗口中，将源码复制到 Tests/Integration，运行 make bootstrap，再执行：

```bash
xcodebuild test -project CamCardReplica.xcodeproj -scheme CamCardReplica \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:CamCardReplicaTests/ReviewCorpusProbeTests
```

完成后移除临时测试文件并重新生成工程。不要与 UI 测试并用同一模拟器。逐张 autoreleasepool 是批量测量的内存管理，不修改 App 的生产实现。

计分：忽略大小写、首尾空白；保留号码内部格式；电话/邮箱比较整个集合；nil 与空集合对应字段缺失。统计包含“本来就缺该字段且输出也为空”的正确项，不能误读成只针对已印刷字段的召回率。
