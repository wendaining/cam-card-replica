import SwiftUI

enum Theme {
    static let cornerRadius: CGFloat = 14
    static let cardSpacing: CGFloat = 12
    static let thumbnailSize: CGFloat = 56

    static var cardBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    static var screenBackground: Color {
        Color(uiColor: .systemGroupedBackground)
    }
}

/// Small filled pill used for tags.
struct TagChip: View {
    let name: String
    var selected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Text(name)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? Color.accentColor : Color.accentColor.opacity(0.12))
            .foregroundStyle(selected ? Color.white : Color.accentColor)
            .clipShape(Capsule())
            .accessibilityIdentifier(A11y.tagChip(name))
            .contentShape(Capsule())
            .onTapGesture { onTap?() }
    }
}

/// Empty states are part of the spec (T01) and are easy to get wrong: they must
/// explain the next action, not just say "no data".
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(A11y.emptyState)
    }
}
