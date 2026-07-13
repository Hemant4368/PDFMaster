import SwiftData
import SwiftUI
import VisionKit

struct ScannerFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showScanner = true
    @AppStorage("scanner.colorMode") private var colorMode: ScanColorMode = .color
    @AppStorage("scanner.quality") private var quality: PDFQuality = .balanced

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.scannedImages.isEmpty {
                    EmptyStateView(title: "Ready to scan", message: "Use the camera scanner for edge detection, perspective correction, and multipage capture.", systemImage: "viewfinder")
                        .padding()
                } else {
                    preview
                }
            }
            .navigationTitle("Scan to PDF")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Scan") { showScanner = true }
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .sheet(isPresented: $showScanner) {
                if VNDocumentCameraViewController.isSupported {
                    DocumentScannerView { images in
                        viewModel.scannedImages = images
                    } onCancel: {
                        if viewModel.scannedImages.isEmpty { dismiss() }
                    }
                    .ignoresSafeArea()
                } else {
                    Text("Document camera is not available on this device.")
                        .padding()
                }
            }
            .navigationDestination(item: $viewModel.savedDocument) { document in
                PDFViewerView(document: document)
            }
            .overlay {
                if viewModel.isSaving { LoadingOverlay(title: "Creating PDF") }
            }
            .alert("Scanner", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 18) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(viewModel.scannedImages.enumerated()), id: \.offset) { index, image in
                        VStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 210)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                            Text("Page \(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            TextField("PDF name", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
            VStack(spacing: 8) {
                Picker("Color Mode", selection: $colorMode) {
                    ForEach(ScanColorMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                Picker("Quality", selection: $quality) {
                    ForEach(PDFQuality.allCases) { q in
                        Text(q.rawValue).tag(q)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, 20)
            PrimaryButton(title: "Save in files", systemImage: "tray.and.arrow.down.fill") {
                viewModel.save(modelContext: modelContext)
            }
            .disabled(!viewModel.canSave)
            .padding(.horizontal, 20)
            Spacer()
        }
        .padding(.top)
    }
}
