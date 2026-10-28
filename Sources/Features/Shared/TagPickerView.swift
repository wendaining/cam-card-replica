import SwiftUI

/// Tag editing (spec 十一): create, attach, remove.
struct TagPickerView: View {
    @Binding var draft: CardDraft
    @Environment(AppServices.self) private var services

    @State private var isAdding = false
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !knownTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(knownTags, id: \.self) { tag in
                            TagChip(name: tag, selected: draft.tags.contains(tag)) {
                                toggle(tag)
                            }
                        }
                    }
                }
            }
            HStack(spacing: 16) {
                Button {
                    newTag = ""
                    isAdding = true
                } label: {
                    Label("新建标签", systemImage: "tag")
                        .font(.footnote)
                }

                if !knownTags.isEmpty {
                    Menu {
                        ForEach(knownTags, id: \.self) { tag in
                            Button(role: .destructive) {
                                draft.deleteTag(named: tag)
                            } label: {
                                Label("删除「\(tag)」", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label("删除标签", systemImage: "tag.slash")
                            .font(.footnote)
                    }
                    .accessibilityIdentifier("delete-tag-menu")
                }
            }
            .alert("新建标签", isPresented: $isAdding) {
                TextField("标签名称", text: $newTag)
                    .accessibilityIdentifier("new-tag-field")
                Button("取消", role: .cancel) {}
                Button("添加") { createTag() }
            } message: {
                Text("例如 Conference、Professor、Customer")
            }
        }
    }

    private var knownTags: [String] {
        let fromLibrary = services.library.tags.map(\.name)
        return Array(Set(fromLibrary + draft.tags)).filter { tag in
            !draft.deletedTags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
        }.sorted()
    }

    private func toggle(_ tag: String) {
        if let index = draft.tags.firstIndex(of: tag) {
            draft.tags.remove(at: index)
        } else {
            draft.tags.append(tag)
        }
    }

    private func createTag() {
        draft.createTag(named: newTag, knownTags: services.library.tags)
    }
}
