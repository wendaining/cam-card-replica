# ADR-0001：OCR 与名片边界检测使用 Apple Vision

- 状态：接受
- 日期：2026-10-27

## 背景

作业要求把名片图像转成结构化联系人，并且要能对固定语料量化评测。
候选：云 OCR（百度/腾讯/Azure）、第三方 SDK（ML Kit）、Apple Vision。

## 决策

使用 Apple Vision：`VNRecognizeTextRequest`（`accurate`，`zh-Hans`+`en-US`）做 OCR，
`VNDetectRectanglesRequest` 做名片边界，Core Image `CIPerspectiveCorrection` 做校正。

## 理由

1. **确定性**：同一张图同一系统版本输出稳定，评测数字可复现；云 API 会随模型更新漂移。
2. **离线**：无网络、无配额、无密钥，CI 可跑。
3. **中文支持足够**：简体中文与英文混排是本作业的主要场景。
4. **零依赖/零成本**：不违反"不引第三方依赖"的工程约定。
5. 作业明确说"不要求复现 CamCard 的内部算法"，用系统能力是合理取舍。

## 代价

- 竖排、艺术字、强反光效果差 → 写入已知限制，并用错误分析量化。
- 仅限 Apple 平台 → 本作业只要求 iOS。

## 后果

- OCR 相关测试可以在模拟器上跑，不需要真机。
- 准确率上限受系统模型限制，报告里要如实说明。
