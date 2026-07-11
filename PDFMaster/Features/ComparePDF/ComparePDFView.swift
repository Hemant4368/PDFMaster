import SwiftUI

struct ComparePDFView: View {
    @State private var leftURL: URL?
    @State private var rightURL: URL?
    @State private var showLeftPicker = false
    @State private var showRightPicker = false

    var body: some View {
        VStack(spacing: 0) {
            selectorBar
            Divider()

            if leftURL != nil || rightURL != nil {
                HStack(spacing: 1) {
                    pdfPane(url: leftURL, side: "Left")
                    Divider()
                    pdfPane(url: rightURL, side: "Right")
                }
            } else {
                emptyState
            }
        }
        .navigationTitle("Compare PDF")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLeftPicker) {
            DocumentPickerView(allowsMultipleSelection: false) { leftURL = $0.first }
        }
        .sheet(isPresented: $showRightPicker) {
            DocumentPickerView(allowsMultipleSelection: false) { rightURL = $0.first }
        }
    }

    private var selectorBar: some View {
        HStack(spacing: 0) {
            fileButton(label: leftURL?.lastPathComponent ?? "PDF 1", color: .blue) {
                showLeftPicker = true
            }
            Divider().frame(height: 40)
            fileButton(label: rightURL?.lastPathComponent ?? "PDF 2", color: .purple) {
                showRightPicker = true
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder private func fileButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
        }
    }

    @ViewBuilder private func pdfPane(url: URL?, side: String) -> some View {
        if let url {
            PDFKitView(url: url, allowsDocumentInteraction: true)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.title)
                    .foregroundStyle(.quaternary)
                Text("Tap to choose \(side)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.arrow.right.square")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.primary.opacity(0.4))
            Text("Select two PDFs")
                .font(.title3).bold()
            Text("Choose a PDF for each side to compare them side by side.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
