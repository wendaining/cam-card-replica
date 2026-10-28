# 审查修复记录（2026-10-28）

基线为修复前审查 7c938f5。按 SDD 先读规格、增加反例并确认红灯，再修实现、复验并更新追溯。本地修复不代表正版行为等价已签收。

## 逐项结果

| 审查项 | 本地处理 | 验证 |
|---|---|---|
| R01 保存失败/删除丢图 | throws 传播；候选库提交后发布；失败新增清图、成功删除后清图；损坏库禁止覆盖 | 失败 store、第二图失败、重试、编辑/两图文件回读、UI 存储失败 |
| R02 图片入口 | 可访问按钮打开全屏查看，可切原图 | 扫描保存后打开/切换/关闭 UI |
| R03 导出过期 | ShareLink 使用当前记录的 VCardDocument，分享时写独立文件 | 编辑后 VCF 反序列化全部映射，同名隔离 |
| R04 检测比例 | Vision 参数转换为倒数区间 | 宽卡正例、方形反例、原照片/遮挡 |
| R05–R07 电话与网址 | 最近标签分类；排除邮箱/网址数字；域名结束边界防截断，带明确证据的新后缀网址保留完整值 | 混合标签、数字邮箱/ID/URL、完整后缀/路径反例；原文本门槛 |
| R08 标签大小写 | 写入口统一规范名称；筛选/删除大小写一致 | 保存→过滤→删除→回读 |
| R09 删除确认 | 列表与详情都二次确认；滑动全删禁用 | 取消保留、确认移除；磁盘失败保图 |
| R10 取消与标签 | 任意阶段一次退出；标签创建/全库删除随草稿一次提交 | 取消不增标签、失败回滚、跨名片删除原子性 |
| R11–R12 错误/后台 | 裁剪页显示识别错误；检测/校正/OCR/解析后台执行，token 过滤迟到结果 | 阻塞 recognizer 主线程仍响应、取消/重试/空识别 UI |
| R13 正版等价 | 需要外部观察，尚未验收 | 单列 external-acceptance；不编造版本或截图 |
| R14 全字段测量 | 保留原文本门槛；完整多值/缺失/错值统计；全76图真实 Vision 测量并附 xcresult | 集合计分反例、完整图片覆盖；图像测量单列 |
| R15 识别证据 | Codable 可选 recognition；旧 JSON 兼容，编辑保留初始字段/逐行 OCR | 人工修改→再次编辑→文件回读、旧 JSON 解码 |
| R16 字体 | 语料 v2 按编号轮换真实字体族；GT/manifest 记录；fixture 同步 | Python 字体覆盖、全文件两次 SHA-256 相等、业务 GT 未变 |
| R17 运行命令 | build/install 统一 derivedDataPath；指定设备安装；脚本复用 make verify；bench 启用 pipefail | 工具测试、实际 make run |

## 红灯证据

- 存储反例：原实现12个仓库测试中6处断言失败；内存未回滚，删除先丢图片。修复后17个针对性测试通过，后续又增加标签/损坏库回归。
- 原图按钮和取消标签用例在原实现失败；取消用例加上“不再处于 scanner”断言，避免只检查底层名片夹存在的假绿。
- 电话/网址/检测正反例在原实现失败；后台测试原先识别结束才回到主线程，processing 断言失败。
- recognition 快照在原实现为 nil；工具测试证明旧路径不含 derivedDataPath、原字体选择没有实际轮换。
- UI 删除回归同时验证系统原生弹窗取消与确认；iOS 27/iPad 的 popover 需用外部区域取消，确认按钮须限定到弹窗，不能误点底层滑动按钮。
- iPad 回归抓到图片按钮的可访问性范围大于实际点击区域；已把缩略图居中并让整行成为点击区域，原图切换与重启后的图片查看因此能按可访问按钮正常操作。
- iPad 的多行 TextField 被系统自动化报告为 Group，导致备注定位和动画等待异常；备注改用标准 TextEditor，保留占位提示。此问题是在真实进程重启回归中发现，文件库回读本身正常。

## 指标与未完成验收

原理想文本门槛没有下调。完整检查显式记录无标签传真误归座机的已知限制，XCTExpectFailure 只用于该已披露歧义，统计照常计错；不能宣称所有字段误填率为零。图像测量中的 Vision 错字也不隐藏、不按语料硬编码修正。

- 理想文本与图像结果见 ocr-accuracy 和 image-accuracy-latest。
- 真机相机/权限/系统通讯录/实拍质量、正版 CamCard 对比见 `docs/testing/external-acceptance.md`。
- 系统 PhotosPicker 实际选取与取消单独留证，不把 fixture 按钮当作系统选择器。
- 远端 CI 未推送运行；本地通过不能冒充远端结果。

## 最终本地验证

环境：macOS 27.0.1、Xcode 27.1、iOS/iPadOS 27.0；2026-10-28 在当前修复版本串行完成。

| 命令/检查 | 实际结果 |
|---|---|
| make verify | lint、build、93个单元/集成测试通过，0个非预期失败；含1个明确披露的无标签传真归类期望失败 |
| make test-ui | iPhone 18 Pro，24个方法通过（23个功能回归+1个截图），326.3秒 |
| make test-ipad | iPad Pro 11-inch (M5)，同一套24个方法通过，319.3秒 |
| make bench + report_benchmark.py | 全部76张图真实 Vision 链路完成，报告已更新；原理想文本门槛未下调 |
| make test-tooling | 3个 Python 检查通过：构建/安装路径、实际字体覆盖、文本不越画布 |
| 语料复现 | 两次生成全部图片、GT、manifest、fixture 的 SHA-256 相同；业务 GT 与 v1 相同 |
| make run | 默认 build 和全新 /tmp/camcard-review-fresh-build 两个输出目录均实际编译、指定设备安装、启动成功，构建产物与安装路径一致 |
| make audit / git diff --check | 文档事实审计0个问题；无空白错误 |

上述完整运行的本机日志分别为 `/tmp/camcard-final4-verify.log`、`/tmp/camcard-final3-ui.log`、`/tmp/camcard-final3-ipad.log`、`/tmp/camcard-final2-bench.log`、`/tmp/camcard-final-run.log`、`/tmp/camcard-fresh-run.log`；日志是本机临时证据，核心结果和截图随仓库保存。最终 verify 在整行召回指标更名后再次执行，93个测试通过，执行57.6秒；指标门槛与生产逻辑未改，UI 使用前述完整运行证据。正式回归在 Tests/UITests 中，修复前探针仅适用于基线。

### 系统 PhotosPicker 手动验证（T05）

在 iPhone 18 Pro 模拟器上使用系统照片选择器，素材仅为合成名片。启动只打开 fixture-camera 以避开不存在的相机硬件；没有使用测试名片按钮，检测/校正/Vision/解析均为生产实现，库使用 FileCardStore。

1. 打开系统选择器，取消后返回扫描页。
2. 再次打开，选择合成名片，自动进入裁剪页。
3. 确认裁剪，进入有识别字段的确认页。
4. 一次取消返回名片夹；操作前后容器内全部5个 library.json（含之前的隔离测试库）SHA-256 相同。

证据：[系统选择器](screenshots/photos-picker/01-system-picker.png)、[导入后裁剪](screenshots/photos-picker/02-imported-crop.png)、[识别确认](screenshots/photos-picker/03-recognized-review.png)、[取消回列表](screenshots/photos-picker/04-cancelled-library.png)。这证明本次模拟器系统选图交互，不替代真机相机、通讯录或正版行为签收。
