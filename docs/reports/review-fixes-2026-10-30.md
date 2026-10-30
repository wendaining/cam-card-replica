# 全仓审查修复记录（2026-10-30）

范围是本轮全仓审查发现的七项问题。基线为 127fa4f；逐项增加反例、确认修复前失败、修实现、验证并小增量提交。未改变测试图片、Ground Truth、依赖或原有评测门槛。

## 修复与提交

| 编号 | 问题与修复 | 提交 | 回归证据 |
|---|---|---|---|
| R18 | 邮箱/网址中的关键词不再生成公司、职位、部门；兼容带公司名的连写法律后缀 | 02db310 + 本报告所在的兼容补丁提交 | `testInternetAddressesDoNotInventOrganizationFields`、`testDottedCompanySuffixSurvivesInternetAddressMasking` |
| R19 | 联系方式内部数字不再当成邮编/地址 | 34caf21 | `testContactDigitsDoNotInventPostalAddress`，邮箱、电话、网址及真实地址对照 |
| R20 | 净分不正的公司候选不再强选为职位 | cda2c6a | `testNegativeTitleCandidateRemainsACompany`，中英文公司与独立职位 |
| R21 | 明确地址标签或门牌号＋街道词可识别短地址 | 0dcbf90 | `testShortStreetAddressUsesLabelOrHouseNumberEvidence`，同时排除空标签及孤立街道词 |
| R22 | 座机/传真同号分别保留，同类型格式重复仍去重 | 1c4158e | `testSharedOfficeAndFaxNumberPreservesBothKinds`，顺序、同行、草稿及导出 |
| R23 | 相册加载共用流程版本检查，忽略旧成功/失败以及取消后的回调 | b232f04 | ScanFlowModel 的可控异步加载测试：替换图片、保留新草稿、当前错误、重拍、任务取消及提前取消 |
| R24 | 首页区分读取失败和空库，提供重试；恢复前禁用扫描 | b9b243b | `testReloadRecoversReadFailureWithoutReplacingStoredCards`、`testT20_libraryLoadFailureShowsRetryInsteadOfEmptyState` |

## 验证

- 每个提交前运行 make verify；五个解析修复及最后的兼容补丁另外运行 make bench。
- R23 先原样提取相册加载入口供控制完成顺序，确认新测试在旧行为下失败，再加入版本和取消检查。
- R24 先注入首次读取失败，确认原首页无法展示错误；随后验证重试能读回原有名片，而不是清空库。损坏 JSON 不被覆盖的原有文件测试继续保留。
- 最终兼容补丁的 make verify：当时104个测试通过（单元/集成），0个非预期失败，执行56.3秒。无标签号码的既有期望失败仍明确保留。
- 新增首页读取失败 UI 用例先红后绿，单独回归通过。完整 iPhone UI：24个功能用例通过，1个截图用例按默认配置跳过，执行307.4秒；iPad 本轮未重跑。
- make audit 与 git diff --check 通过。

解析器五项修复与兼容补丁的实测数字逐步写入 [OCR 准确率报告](ocr-accuracy.md)。同一批76张图的统计没有变化：本轮修的是原语料未触发的边界问题，不能据此声称图像 OCR 准确率提高。邮箱、地址的真实图像错误与无标签号码歧义仍需如实计入。

收尾复查发现 R18 的网址屏蔽会误屏蔽带公司名的 Co.Ltd 连写后缀；与基线对照后增加第八个小提交修复。新增测试同时检查公司后缀、裸域名、邮箱标签和明确网址，防止重新放开邮箱/网址误填。

本地临时日志位于 /tmp/camcard-fix1-red.log 至 /tmp/camcard-fix8-red.log；各步验证使用对应的 verify/bench 日志，R23 的最终验证为 /tmp/camcard-fix6-final-verify.log，最终 UI 为 /tmp/camcard-final-ui.log，兼容补丁使用 /tmp/camcard-fix8-verify.log 和 /tmp/camcard-fix8-bench.log。可复现的回归测试和关键结论保存在仓库中，临时日志不是交付依赖。

## 验收边界

本轮不代表作业全部验收。真机相机/权限、真机通讯录、真机杀进程、正版 CamCard 同图与页面对比、最终作业报告仍按外部验收清单补证。相册竞态通过注入可控加载复现；真实 PhotosPicker 手动证据沿用 2026-10-28 记录，本轮未重新操作系统选择器。

## 手动检查后的增量修复

### R25 整图路径保留输入像素

“使用整张图片”或未检测到边界时，App 仍经过一次 Core Image 透视渲染。对 en-02.jpg 和 zh-01.jpg 的新增回归证明：这一步即使不改变尺寸，也会改变已解码像素；小字识别结果因此可能与直接识别原图不同。现在 fullFrame 直接返回原图，手动四角校正路径不变。

新增用例先出现两次像素一致性失败，再修复；make verify 通过，105个单元/集成测试方法。此项保证整图路径不损伤输入，不宣称修复所有 OCR 错字。手动观察到的邮箱、地址和无标签传真错误继续按真实图像评测统计。
