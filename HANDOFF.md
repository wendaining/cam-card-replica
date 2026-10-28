# HANDOFF — 审查修复后的接手说明

> 最近更新：2026-10-28。先读 AGENTS.md，再读审查修复报告和验收矩阵。不要把测试方法数量当作验收覆盖率，也不要把理想文本准确率当成图像准确率。

## 合并与分支状态

- [PR #1](https://github.com/wendaining/cam-card-replica/pull/1) 已于2026-10-28合并到 main，合并提交为 `058fa4108fc86a7b3df26a2e39fa746f03ee8c82`。
- 用户已明确决定依据本地完整测试及无冲突检查先合并，GitHub Actions 的计费问题后续处理；这不表示远端 CI 已通过。
- 本地已切回 main，并从 origin/main 快进同步上述合并提交；本次交接更新基于合并后的 main。
- `.dsh-computer-use/` 已加入 gitignore，电脑工具产物保留在本地，不入库。

## 当前实现

- SwiftUI / iOS 17+，Vision + Core Image，纯规则解析，自写 Codable JSON/图片存储，无第三方 SPM。
- 新增/编辑/标签先提交 JSON 再发布内存；失败 throws，表单保留并提示。新增中途失败清理新图片，删除在 JSON 成功后才清理图片。
- 原图查看有可访问按钮；导出使用当前已保存字段的 VCardDocument，不缓存过期 VCF。
- 任意扫描阶段一次取消退出；表单标签操作仅修改草稿，保存时一次提交。
- 检测、校正、OCR 在后台；任务 token 防止取消后的迟到结果刷新界面。
- recognition 保存逐行 OCR 与修改前字段/evidence；旧 JSON 缺字段可继续读取。
- 比例转换、混合电话标签、数字邮箱误识别电话、网址截断与标签大小写均有回归用例。

## 运行与证据

```bash
make bootstrap
make verify
make test-ui
make test-ipad
make bench
python3 Scripts/report_benchmark.py
make audit
```

当前正式目标包含93个单元/集成方法、24个 UI 方法（含截图）；T01–T20 是20条定义的验收场景，部分仍需外部补验。最终运行结果及红/绿记录见 `docs/reports/review-fixes-2026-10-28.md`。

2026-10-28 完整 make verify、iPhone/iPad UI、bench、工具测试、audit 已通过。T05 真实系统 PhotosPicker 选取/取消已手动留证，取消前后文件库哈希一致；make run 实际安装启动成功。

语料 v2 仍为50张合成名片/76张图，业务 GT 未改，按编号轮换真实字体族并同步9个 fixture。运行生成器需要 Pillow、NumPy；可用 `make testdata PYTHON=<具备依赖的解释器>`。重复生成的图片、GT、manifest、fixture 已做逐文件哈希对比。不要手工改图片。

概率指标分开读：原理想文本首值门槛继续保留；完整集合、全部缺失字段、真实76张图另行测量。无标签座机/传真的歧义被显式计错并标为已知期望失败，不能宣称所有字段误填率为零。见 ADR-0006 与准确率报告。

## 剩余待验与交付项

| 项目 | 尚需补齐的证据 |
|---|---|
| T03 真机权限 | 全新安装允许/拒绝相机权限、系统设置开启后返回 App 恢复拍摄 |
| T04 真机相机 | 清晰/倾斜名片拍摄→预览/重拍→四角调整→OCR→人工确认→保存 |
| T18 真机杀进程 | 保存字段修改、标签、备注与原图/校正图，上划关闭后重开逐项核对；模拟器独立文件库 terminate/launch 已自动化通过 |
| T19 真机通讯录 | 授权/拒绝两条路径；实际写入合成联系人后在系统通讯录核对全部字段与电话标签；VCF 映射和编辑后最新值已在本地验证 |
| 真实拍照质量 | 反光、阴影、模糊、旋转等实拍的识别错误与人工校正次数；竖排文字仍是已知限制，合成照片不能代表这些质量分布 |
| 正版 CamCard 对比 | 锁定版本、iOS、设备、语言、登录/会员范围；同一批 v2 语料逐页截图、T01–T20 行为观察、同图识别差异与回归，补 difference-analysis |
| 远端 CI | 恢复 GitHub Actions 付款/消费额度后，对最新 main 重跑完整工作流；当前失败是作业未启动，尚无远端编译/测试结果 |
| 最终报告 | 外部证据签收后更新差异分析、验收矩阵和 final-report，再定稿行为等价结论 |

按 `docs/testing/external-acceptance.md` 收集设备、版本、日期、结果和截图/录屏；本地修复不冒充上述验收完成。T05 真实系统 PhotosPicker 选取/取消已在模拟器手动留证，不再列为待验。

## 文档边界

- `docs/reports/review-2026-10-28.md` 与对应 evidence 目录是修复前基线 7c938f5 的历史快照，不代表当前源码；其中旧探针仅可在基线运行。
- 产品/spec/API/追溯表描述当前契约；最终报告仍需等外部验收后定稿。
- CI 工作流中的 UI 测试不再忽略失败。PR 已按用户决定合并；[合并提交的 CI](https://github.com/wendaining/cam-card-replica/actions/runs/40662086654) 仍因账户付款/消费额度限制未启动任何步骤，不能算作编译或测试失败，也不能当作远端验证通过。详见修复记录；计费与远端复验仍待处理。
