import PDFKit
import SwiftUI

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .redButtonStyle()
            } else {
                Text(title)
                    .redButtonStyle()
            }
        }
    }
}

struct ToolCard: View {
    let tool: PDFTool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: tool.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tool.accent)
                .frame(width: 44, height: 44)
                .background(tool.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(tool.rawValue)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .premiumCard(padding: 14)
    }
}

struct DocumentRow: View {
    let document: DocumentRecord
    let thumbnail: UIImage?
    let isSelectionMode: Bool
    let isSelected: Bool
    let action: () -> Void
    let toggleSelection: () -> Void
    let share: () -> Void
    let rename: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: isSelectionMode ? toggleSelection : action) {
            HStack(spacing: 14) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.primary : .secondary)
                        .transition(.scale.combined(with: .opacity))
                }

                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "doc.richtext.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppTheme.primary.opacity(0.08))
                    }
                }
                .frame(width: 48, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(document.fileSize.formattedFileSize) • \(document.pageCount) page\(document.pageCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !isSelectionMode {
                    Button(action: share) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    Menu {
                        Button(action: rename) {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(action: duplicate) {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        Button(action: share) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive, action: delete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 84, height: 84)
                .background(AppTheme.primary.opacity(0.1))
                .clipShape(Circle())
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

struct LoadingOverlay: View {
    let title: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(AppTheme.primary)
                Text(title)
                    .font(.headline)
            }
            .premiumCard()
        }
    }
}
