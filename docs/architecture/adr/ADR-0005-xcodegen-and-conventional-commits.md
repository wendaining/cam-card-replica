# ADR-0005：XcodeGen 生成工程 + Conventional Commits

- 状态：接受
- 日期：2026-10-27

## 决策

- `.xcodeproj` 不入库，由 `project.yml` + `xcodegen generate` 生成（`make bootstrap`）。
- 提交信息强制 Conventional Commits，由 `.githooks/commit-msg` 校验。
- 本地 `make verify` 作为主门禁；GitHub Actions 在 macOS runner 上复跑。

## 理由

1. `.xcodeproj` 是巨型 plist，多人/多 agent 并行时冲突几乎无法手工合并；
   `project.yml` 是文本，diff 可读，冲突可解。
2. 新人/新会话只需 `make bootstrap`，不会出现"工程文件坏了"。
3. 约定式提交让 `git log` 直接可读，也便于生成变更记录。

## 代价

- 每次改文件结构要重新 generate（`make bootstrap`）。
- 需要安装 xcodegen（brew）。

## 后果

CI 的第一步固定是 `make bootstrap`。
