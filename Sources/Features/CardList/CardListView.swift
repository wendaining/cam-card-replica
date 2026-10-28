import SwiftUI

struct CardListView: View {
    @Environment(AppServices.self) private var services
    var onScan: () -> Void

    @State private var query = ""
    @State private var selectedTag: String?
    @State private var errorMessage: String?
    @State private var pendingDeletion: [BusinessCard] = []
    @State private var showDeleteConfirmation = false

    private var allCards: [BusinessCard] {
        services.library.cards
    }

    private var visibleCards: [BusinessCard] {
        services.library.cards(matching: query, tag: selectedTag)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if !services.library.tags.isEmpty {
                tagBar
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.screenBackground)
        .navigationTitle("名片夹")
        .onChange(of: services.library.tags) { _, tags in
            if let selectedTag, !tags.contains(where: { $0.name == selectedTag }) {
                self.selectedTag = nil
            }
        }
        .alert("操作失败", isPresented: Binding(get: { errorMessage != nil }, set: {
            if !$0 {
                errorMessage = nil
            }
        })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .confirmationDialog("删除选中的名片？", isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible, presenting: pendingDeletion) { victims in
            Button("删除", role: .destructive) {
                do { try services.library.delete(at: IndexSet(victims.indices), in: victims) } catch {
                    errorMessage = error.localizedDescription
                }
                pendingDeletion = []
            }
            Button("取消", role: .cancel) { pendingDeletion = [] }
        } message: { _ in Text("删除后无法恢复，原始图片也会一并移除。") }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onScan) {
                    Image(systemName: "plus.viewfinder")
                }
                .accessibilityIdentifier(A11y.scanButton)
                .accessibilityLabel("扫描名片")
            }
        }
    }

    // MARK: - Pieces

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索姓名、公司、电话、邮箱", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(A11y.searchField)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChip(name: "全部", selected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(services.library.tags) { tag in
                    TagChip(name: tag.name, selected: selectedTag == tag.name) {
                        selectedTag = selectedTag == tag.name ? nil : tag.name
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier(A11y.tagFilter)
    }

    @ViewBuilder
    private var content: some View {
        if allCards.isEmpty {
            EmptyStateView(
                title: "还没有名片",
                message: "扫描或导入一张名片，开始建立你的名片夹。",
                systemImage: "rectangle.portrait.on.rectangle.portrait",
                actionTitle: "扫描名片",
                action: onScan
            )
        } else if visibleCards.isEmpty {
            EmptyStateView(
                title: "没有匹配的名片",
                message: "换个关键词或标签试试。",
                systemImage: "magnifyingglass"
            )
        } else {
            List {
                ForEach(visibleCards) { card in
                    NavigationLink(value: card.id) {
                        CardRow(card: card, thumbnail: thumbnail(for: card))
                            .accessibilityIdentifier(A11y.cardRow(card.id))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("删除") {
                            pendingDeletion = [card]
                            showDeleteConfirmation = true
                        }
                        .tint(.red)
                    }
                }
            }
            .listStyle(.plain)
            // Paint the scroll view's own background: the rows are white, and
            // without this the empty space under the last row showed the screen
            // background instead, which read as a clipped list.
            .background(Color(uiColor: .systemBackground))
            .scrollContentBackground(.hidden)
            .readableWidth(880)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(A11y.cardList)
        }
    }

    private func thumbnail(for card: BusinessCard) -> CGImage? {
        guard let data = services.library.imageData(for: card) else { return nil }
        return ImageCoding.cgImage(from: data)
    }
}

#Preview {
    RootView()
        .environment(AppServices.make(arguments: ["-ui-testing"]))
}
