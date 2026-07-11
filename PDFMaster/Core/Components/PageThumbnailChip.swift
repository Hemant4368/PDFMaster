import PDFKit
import SwiftUI

struct PageThumbnailChip: View {
    let pdfURL: URL
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    thumbnailImage
                        .frame(width: 62, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isSelected ? AppTheme.primary : Color(.separator),
                                    lineWidth: isSelected ? 2.5 : 0.5
                                )
                        )
                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.primary)
                            .background(Circle().fill(.white).padding(2))
                            .offset(x: 8, y: -8)
                    }
                }

                Text("\(index + 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? AppTheme.primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .task(id: pdfURL) { await load() }
    }

    @ViewBuilder private var thumbnailImage: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .background(Color.white)
        } else {
            Color(.secondarySystemBackground)
                .overlay { ProgressView().scaleEffect(0.7) }
        }
    }

    private func load() async {
        thumbnail = await Task.detached(priority: .userInitiated) {
            guard let doc = PDFDocument(url: pdfURL),
                  let page = doc.page(at: index) else { return nil }
            return page.thumbnail(of: CGSize(width: 124, height: 164), for: .cropBox)
        }.value
    }
}
