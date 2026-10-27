import SwiftUI

/// Card detail + edit + export + delete (spec 十, T13/T14/T19).
struct CardDetailView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    let cardID: UUID

    @State private var isEditing = false
    @State private var draft = CardDraft()
    @State private var showDeleteConfirmation = false
    @State private var showRawText = false
    @State private var vCardURL: URL?
    @State private var alertMessage: String?
    @State private var showAlert = false

    private var card: BusinessCard? { services.library.card(id: cardID) }

    var body: some View {
        Group {
            if let card {
                content(for: card)
            } else {
                EmptyStateView(
                    title: "名片不存在",
                    message: "它可能已被删除。",
                    systemImage: "questionmark.folder"
                )
            }
        }
        .navigationTitle(isEditing ? "编辑名片" : "名片详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .confirmationDialog("删除这张名片？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) { delete() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，原始图片也会一并移除。")
        }
        .alert("提示", isPresented: $showAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showRawText) {
            RawTextSheet(text: card?.rawText ?? "", lines: [])
        }
        .task(id: cardID) {
            prepareVCard()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for card: BusinessCard) -> some View {
        Form {
            Section {
                cardImage(for: card)
            }
            .listRowBackground(Color.clear)

            if isEditing {
                CardFieldsForm(draft: $draft)
                Section {
                    Button("取消") {
                        isEditing = false
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.name).font(.title2.bold())
                        if let title = card.jobTitle, !title.isEmpty {
                            Text(title).font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let company = card.company, !company.isEmpty {
                            Text(company).font(.subheadline)
                        }
                        if let department = card.department, !department.isEmpty {
                            Text(department).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier(A11y.field(.name))
                }

                Section("联系方式") {
                    ForEach(card.sortedPhones) { phone in
                        contactRow(
                            title: phone.number,
                            subtitle: phone.kind.displayName,
                            systemImage: phone.kind.systemImage,
                            url: URL(string: "tel://\(phone.dialable)")
                        )
                    }
                    ForEach(card.emails, id: \.self) { email in
                        contactRow(
                            title: email,
                            subtitle: "邮箱",
                            systemImage: "envelope",
                            url: URL(string: "mailto:\(email)")
                        )
                    }
                    if let website = card.website, !website.isEmpty {
                        contactRow(
                            title: website,
                            subtitle: "网站",
                            systemImage: "globe",
                            url: URL(string: website.hasPrefix("http") ? website : "https://\(website)")
                        )
                    }
                    if let address = card.address, !address.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                            Text(address).font(.subheadline)
                        }
                    }
                }

                if !card.tags.isEmpty {
                    Section("标签") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(card.tags, id: \.self) { tag in
                                    TagChip(name: tag, selected: true)
                                }
                            }
                        }
                    }
                }

                if let notes = card.notes, !notes.isEmpty {
                    Section("备注") {
                        Text(notes).font(.subheadline)
                    }
                }

                Section {
                    Button {
                        showRawText = true
                    } label: {
                        Label("查看识别原文", systemImage: "text.alignleft")
                    }
                    .disabled((card.rawText ?? "").isEmpty)
                    LabeledContent("创建时间", value: card.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("更新时间", value: card.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.detailView)
    }

    @ViewBuilder
    private func cardImage(for card: BusinessCard) -> some View {
        if let data = services.library.imageData(for: card, original: false),
           let image = ImageCoding.cgImage(from: data) {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            EmptyView()
        }
    }

    private func contactRow(title: String, subtitle: String, systemImage: String, url: URL?) -> some View {
        Button {
            if let url { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage).foregroundStyle(.secondary).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).foregroundStyle(.primary)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isEditing {
                Button("保存") { saveEdits() }
                    .bold()
                    .accessibilityIdentifier(A11y.detailEditSave)
            } else {
                Menu {
                    Button {
                        startEditing()
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .accessibilityIdentifier(A11y.detailEdit)

                    if let vCardURL {
                        ShareLink(item: vCardURL) {
                            Label("导出 vCard", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier(A11y.detailExport)
                    }
                    Button {
                        Task { await saveToContacts() }
                    } label: {
                        Label("保存到通讯录", systemImage: "person.crop.circle.badge.plus")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .accessibilityIdentifier(A11y.detailDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityIdentifier("detail-more")
                }
            }
        }
    }

    // MARK: - Actions

    private func startEditing() {
        guard let card else { return }
        draft = CardDraft(card: card)
        isEditing = true
    }

    private func saveEdits() {
        guard let card, draft.canSave else { return }
        let updated = draft.makeCard(
            id: card.id,
            originalImageID: card.originalImageID,
            processedImageID: card.processedImageID,
            rawText: card.rawText,
            createdAt: card.createdAt
        )
        services.library.update(updated)
        isEditing = false
    }

    private func delete() {
        guard let card else { return }
        services.library.delete(card)
        dismiss()
    }

    private func prepareVCard() {
        guard let card, let data = try? services.exporter.vCard(for: card) else { return }
        let safeName = card.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).vcf")
        try? data.write(to: url, options: .atomic)
        vCardURL = url
    }

    private func saveToContacts() async {
        guard let card else { return }
        do {
            try await services.exporter.saveToContacts(card)
            alertMessage = "已保存到通讯录。"
        } catch {
            alertMessage = error.localizedDescription
        }
        showAlert = true
    }
}
