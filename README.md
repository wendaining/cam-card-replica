# CamCard Replica

用 SwiftUI + Apple Vision 复刻「名片全能王」的**名片数字化 + 联系人管理**功能切片，
配套 SDD 规格、Ground Truth 语料与 T01–T20 验收测试。

```
拍/导入 → 名片检测 → 透视校正 → OCR → 字段解析 → 人工确认 → 保存
        → 名片夹 → 搜索/标签 → 详情/编辑 → 重启仍在 → 导出联系人/vCard
```

## 快速开始

```bash
brew install xcodegen          # 一次性
make bootstrap                 # 生成 Xcode 工程
make verify                    # lint + build + test
open CamCardReplica.xcodeproj  # 用 Xcode 跑模拟器
```

前置：Xcode（含 iOS 模拟器 runtime）。详见 [docs/guides/environment.md](docs/guides/environment.md)。

## 文档

| 文档 | 内容 |
|---|---|
| [AGENTS.md](AGENTS.md) | 工程契约：约束、命令、提交规范、当前状态 |
| [docs/spec/product-spec.md](docs/spec/product-spec.md) | 功能规格（10 个模块 + 20 条场景） |
| [docs/spec/data-model.md](docs/spec/data-model.md) | `BusinessCard` 数据模型与字段规则 |
| [docs/spec/acceptance.md](docs/spec/acceptance.md) | 需求 ↔ 测试 ↔ 代码 追溯矩阵 |
| [docs/api/services.md](docs/api/services.md) | 服务协议（OCR/检测/校正/解析/导出） |
| [docs/architecture/overview.md](docs/architecture/overview.md) | 架构与关键决策 |
| [docs/testing/strategy.md](docs/testing/strategy.md) | 测试策略与语料说明 |
| [docs/reports/ocr-accuracy.md](docs/reports/ocr-accuracy.md) | OCR / 字段抽取准确率与错误分析 |
| [docs/guides/](docs/guides/) | 环境、上手、提交规范 |

## 目录

```
Sources/    应用代码（App / Models / Persistence / Services / Features / DesignSystem / Support）
Tests/      单元与集成测试（含 Ground Truth 评测）
UITests/    T01–T20 端到端测试
TestData/   50 张合成名片 + ground_truth.json
Scripts/    语料生成、评测、构建脚本
docs/       spec / api / architecture / testing / guides / reports
```

## 许可与合规

课程作业用途。所有测试名片、人名、公司、电话、邮箱均为**虚构合成数据**
（`.example` 域名、0000 号码段），不含任何真实个人信息。
