import SwiftUI

struct ComparePDFView: View {
    @State private var leftURL: URL?
    @State private var rightURL: URL?
    @State private var showLeftPicker = false
    @State private var showRightPicker = false
    @State private var options = CompareOptions()
    @State private var showOptions = false

    var body: some View {
        VStack(spacing: 0) {
            selectorBar
            if showOptions {
                optionsBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                        showOptions.toggle()
                    }
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(showOptions ? AppTheme.primary : .secondary)
                }
            }
        }
        .sheet(isPresented: $showLeftPicker) {
            PDFSourcePickerSheet { leftURL = $0.first }
        }
        .sheet(isPresented: $showRightPicker) {
            PDFSourcePickerSheet { rightURL = $0.first }
        }
    }

    private var optionsBar: some View {
        VStack(spacing: 8) {
            Toggle("Sync Scrolling", isOn: $options.syncScroll)
            Toggle("Continuous Scroll", isOn: $options.continuousScroll)
            Toggle("Show Page Numbers", isOn: $options.showPageNumbers)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
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
