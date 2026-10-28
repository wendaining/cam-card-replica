# HANDOFF — 审查修复后的接手说明

> 最近更新：2026-10-28。先读 AGENTS.md，再读审查修复报告和验收矩阵。不要把测试方法数量当作验收覆盖率，也不要把理想文本准确率当成图像准确率。

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

## 还没有的证据

- 正版 CamCard 的版本/语言/设备/登录状态锁定、逐页截图、同图识别和差异回归。
- 真机相机、真实授权/拒绝恢复、系统通讯录落库后的人工核对。
- 真实拍摄的强反光、模糊、阴影与竖排文字；合成照片不能代表这些质量分布。

按 `docs/testing/external-acceptance.md` 收集并签收；本地修复不冒充这些验收已经完成。T18 的 terminate/launch 已有使用独立文件库的 UI 自动化，真机补验仍单列。

## 文档边界

- `docs/reports/review-2026-10-28.md` 与对应 evidence 目录是修复前基线 7c938f5 的历史快照，不代表当前源码；其中旧探针仅可在基线运行。
- 产品/spec/API/追溯表描述当前契约；最终报告仍需等外部验收后定稿。
- CI 的 UI 测试现在是必过步骤。修复分支已推送并建立 [PR #1](https://github.com/wendaining/cam-card-replica/pull/1)，GitHub 报告无冲突；首次远端 CI 因账户付款/消费额度限制未启动任何步骤，不能算作编译或测试失败，也不能当作远端验证通过。详见修复记录；合并仍待决定。
