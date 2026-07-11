import PDFKit
import SwiftUI

struct SelectedPDFPreview: View {
    let url: URL

    @State private var thumbnail: UIImage?
    @State private var pageCount: Int = 0
    @State private var fileSize: Int64 = 0

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView
                .frame(width: 50, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                if pageCount > 0 {
                    Text("\(pageCount) page\(pageCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if fileSize > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.primary)
                .font(.title3)
        }
        .padding(.vertical, 4)
        .task(id: url) { await load() }
    }

    @ViewBuilder private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .background(Color(.secondarySystemBackground))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
                .overlay { ProgressView().scaleEffect(0.8) }
        }
    }

    private func load() async {
        let result = await Task.detached(priority: .userInitiated) { () -> (UIImage?, Int, Int64) in
            guard let doc = PDFDocument(url: url) else { return (nil, 0, 0) }
            let img = doc.page(at: 0)?.thumbnail(of: CGSize(width: 100, height: 132), for: .cropBox)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
            return (img, doc.pageCount, size)
        }.value
        thumbnail = result.0
        pageCount = result.1
        fileSize = result.2
    }
}
