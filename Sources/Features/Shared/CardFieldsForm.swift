import SwiftUI

/// Shared field editor used by the review screen (after OCR) and by the detail
/// screen's edit mode. One implementation means T11 and T14 test the same code.
struct CardFieldsForm: View {
    @Binding var draft: CardDraft
    var showsTags: Bool = true
    var showsNotes: Bool = true
    /// Fields the parser was unsure about; rendered with a "请确认" hint.
    var highlighted: Set<CardField> = []

    var body: some View {
        Section {
            field(.name, text: $draft.name, prompt: "姓名", required: true)
            field(.company, text: $draft.company, prompt: "公司")
            field(.jobTitle, text: $draft.jobTitle, prompt: "职位")
            field(.department, text: $draft.department, prompt: "部门")
        } header: {
            Text("基本信息")
        }

        Section {
            ForEach(PhoneKind.allCases) { kind in
                phoneRows(for: kind)
            }
            emailRows
            field(.website, text: $draft.website, prompt: "网站", keyboard: .URL)
            field(.address, text: $draft.address, prompt: "地址")
        } header: {
            Text("联系方式")
        } footer: {
            if !highlighted.isEmpty {
                Text("带「请确认」的字段识别置信度较低，建议核对后保存。")
            }
        }

        if showsTags {
            Section("标签") {
                TagPickerView(draft: $draft)
            }
        }

        if showsNotes {
            Section("备注") {
                ZStack(alignment: .topLeading) {
                    if draft.notes.isEmpty {
                        Text("添加备注")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 72, maxHeight: 140)
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel("备注")
                        .accessibilityIdentifier(A11y.field(.notes))
                }
            }
        }
    }

    // MARK: - Rows

    private func field(
        _ cardField: CardField,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType = .default,
        required: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Text(required ? "\(prompt) *" : prompt)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .URL ? .never : .words)
                .autocorrectionDisabled(keyboard == .URL)
                .accessibilityIdentifier(A11y.field(cardField))
            if highlighted.contains(cardField) {
                Text("请确认")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func phoneRows(for kind: PhoneKind) -> some View {
        let matching = draft.phones.filter { $0.kind == kind }
        ForEach(matching) { phone in
            HStack(spacing: 8) {
                Text(kind.displayName)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                TextField(kind.displayName, text: binding(forPhone: phone.id))
                    .keyboardType(.phonePad)
                    .accessibilityIdentifier(A11y.field(cardField(for: kind)))
                if highlighted.contains(cardField(for: kind)) {
                    Text("请确认")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        Button {
            draft.phones.append(PhoneNumber(kind: kind, number: ""))
        } label: {
            Label("添加\(kind.displayName)", systemImage: "plus.circle")
                .font(.footnote)
        }
    }

    @ViewBuilder
    private var emailRows: some View {
        ForEach(Array(draft.emails.enumerated()), id: \.offset) { index, _ in
            HStack(spacing: 8) {
                Text(index == 0 ? "邮箱" : "")
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                TextField("邮箱", text: Binding(
                    get: { draft.emails.indices.contains(index) ? draft.emails[index] : "" },
                    set: { newValue in
                        guard draft.emails.indices.contains(index) else { return }
                        draft.emails[index] = newValue
                    }
                ))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier(index == 0 ? A11y.field(.email) : "field-email-\(index)")
            }
        }
        Button {
            draft.emails.append("")
        } label: {
            Label("添加邮箱", systemImage: "plus.circle")
                .font(.footnote)
        }
    }

    // MARK: - Bindings

    private func binding(forPhone id: UUID) -> Binding<String> {
        Binding(
            get: { draft.phones.first { $0.id == id }?.number ?? "" },
            set: { newValue in
                guard let index = draft.phones.firstIndex(where: { $0.id == id }) else { return }
                draft.phones[index].number = newValue
            }
        )
    }

    private func cardField(for kind: PhoneKind) -> CardField {
        switch kind {
        case .mobile: .mobile
        case .office: .office
        case .fax: .fax
        }
    }
}
