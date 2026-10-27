import SwiftUI

struct CardRow: View {
    let card: BusinessCard
    let thumbnail: CGImage?

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
            VStack(alignment: .leading, spacing: 3) {
                Text(card.name)
                    .font(.headline)
                    .lineLimit(1)
                if !card.subtitle.isEmpty {
                    Text(card.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let phone = card.sortedPhones.first?.number {
                    Text(phone)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if !card.tags.isEmpty {
                    Text(card.tags.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(decorative: thumbnail, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Theme.thumbnailSize, height: Theme.thumbnailSize * 0.63)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: Theme.thumbnailSize, height: Theme.thumbnailSize * 0.63)
                .overlay {
                    Text(card.initials)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(2)
                }
        }
    }
}
