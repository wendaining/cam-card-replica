import SwiftUI

/// Human-in-the-loop confirmation (spec 九, T11/T12).
struct ReviewView: View {
    @Environment(AppServices.self) private var services
    @Bindable var model: ScanFlowModel
    var onFinish: () -> Void

    @State private var showRawText = false
    @State private var saveError: String?

    var body: some View {
        Form {
            Section {
                // Compact header: the thumbnail is a sanity check, the fields are
                // the actual work, so they must be reachable without scrolling.
                HStack(spacing: 12) {
                    if let image = model.correctedImage {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .aspectRatio(1.585, contentMode: .fit)
                            .frame(width: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("识别置信度 \(confidenceText)")
                            .font(.subheadline.weight(.medium))
                        Text("请核对下方字段，错误的可以直接改")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Button {
                    showRawText = true
                } label: {
                    Label("查看识别原文", systemImage: "text.alignleft")
                }
                .accessibilityIdentifier(A11y.rawTextButton)
            }

            CardFieldsForm(draft: $model.draft, highlighted: model.lowConfidenceFields)

            if !model.parsed.unassignedLines.isEmpty {
                Section("未归类文字") {
                    ForEach(Array(model.parsed.unassignedLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let saveError {
                Section {
                    Text(saveError).foregroundStyle(.red).font(.footnote)
                }
            }
        }
        .navigationTitle("确认并保存")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.reviewView)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { save() }
                    .bold()
                    .disabled(!model.draft.canSave)
                    .accessibilityIdentifier(A11y.reviewSave)
            }
        }
        .sheet(isPresented: $showRawText) {
            RawTextSheet(text: model.ocr?.rawText ?? "", lines: model.ocr?.lines ?? [])
        }
    }

    private var confidenceText: String {
        String(format: "%.0f%%", model.parsed.overallConfidence * 100)
    }

    private func save() {
        if model.save() != nil {
            onFinish()
        } else {
            saveError = model.errorMessage ?? "保存失败。"
        }
    }
}

/// The raw OCR output is a first-class artifact (spec 7.4): without it the error
/// analysis in `docs/reports/ocr-accuracy.md` would be impossible.
struct RawTextSheet: View {
    let text: String
    let lines: [OCRTextLine]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("原始文本") {
                    Text(text.isEmpty ? "（空）" : text)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
                if !lines.isEmpty {
                    Section("按行置信度") {
                        ForEach(lines) { line in
                            HStack {
                                Text(line.text).font(.footnote)
                                Spacer()
                                Text(String(format: "%.2f", line.confidence))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("OCR 原文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
