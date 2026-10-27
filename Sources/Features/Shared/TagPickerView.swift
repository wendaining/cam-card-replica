import SwiftUI

/// Tag editing (spec 十一): create, attach, remove.
struct TagPickerView: View {
    @Binding var selected: [String]
    @Environment(AppServices.self) private var services

    @State private var isAdding = false
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !knownTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(knownTags, id: \.self) { tag in
                            TagChip(name: tag, selected: selected.contains(tag)) {
                                toggle(tag)
                            }
                        }
                    }
                }
            }
            Button {
                newTag = ""
                isAdding = true
            } label: {
                Label("新建标签", systemImage: "tag")
                    .font(.footnote)
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
        return Array(Set(fromLibrary + selected)).sorted()
    }

    private func toggle(_ tag: String) {
        if let index = selected.firstIndex(of: tag) {
            selected.remove(at: index)
        } else {
            selected.append(tag)
        }
    }

    private func createTag() {
        let name = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        services.library.ensureTag(named: name)
        if !selected.contains(name) {
            selected.append(name)
        }
    }
}
