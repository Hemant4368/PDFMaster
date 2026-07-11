import PhotosUI
import SwiftData
import SwiftUI

private struct ImageEntry: Identifiable {
    let id = UUID()
    var image: UIImage
    var rotation: Int = 0  // 0, 90, 180, 270
}

struct ImageToPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showFilePicker = false
    @State private var entries: [ImageEntry] = []
    @State private var title = "Images PDF"
    @State private var quality: PDFQuality = .balanced
    @State private var orientation: PDFPageOrientation = .portrait
    @State private var pageSize: PDFPageSize = .a4
    @State private var margin: PDFMarginSize = .none
    @State private var mergeIntoOne = true
    @State private var savedDocument: DocumentRecord?
    @State private var savedParts: [DocumentRecord] = []
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $selectedItems, matching: .images) {
                    Label("From Photos", systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    showFilePicker = true
                } label: {
                    Label("From Files App", systemImage: "folder")
                        .foregroundStyle(AppTheme.primary)
                }
            } header: { Text("Add Images") } footer: {
                Text("Supports PNG, JPEG, HEIC, TIFF, BMP, WebP and more.")
            }

            if !entries.isEmpty {
                Section {
                    ForEach($entries) { $entry in
                        imageRow(entry: $entry)
                    }
                    .onMove { entries.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    HStack {
                        Text("Images (\(entries.count))")
                        Spacer()
                        EditButton()
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primary)
                    }
                } footer: {
                    Text("Drag to reorder · Tap rotate or delete on each image.")
                }
            }

            Section("PDF Name") {
                TextField("Output name", text: $title)
            }

            Section("PDF Options") {
                Picker("Orientation", selection: $orientation) {
                    ForEach(PDFPageOrientation.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Page Size", selection: $pageSize) {
                    ForEach(PDFPageSize.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Margin", selection: $margin) {
                    ForEach(PDFMarginSize.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Quality", selection: $quality) {
                    ForEach(PDFQuality.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Merge all images into one PDF", isOn: $mergeIntoOne)
            }

            Section {
                PrimaryButton(title: "Convert to PDF", systemImage: "doc.richtext") { convert() }
                    .disabled(entries.isEmpty || title.isEmpty)
            }

            if !savedParts.isEmpty {
                Section("Saved PDFs") {
                    ForEach(Array(savedParts.enumerated()), id: \.offset) { index, doc in
                        HStack {
                            Label(doc.title, systemImage: "doc.fill")
                                .lineLimit(1)
                            Spacer()
                            ShareLink(item: FileStorageService.fileURL(for: doc.fileName)) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Image to PDF")
        .onChange(of: selectedItems) { _, newItems in loadImages(newItems) }
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerView(contentTypes: [.image], allowsMultipleSelection: true) { urls in
                loadFromFiles(urls)
            }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .overlay { if isWorking { LoadingOverlay(title: "Converting to PDF") } }
        .alert("Image to PDF", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: – Image row

    @ViewBuilder private func imageRow(entry: Binding<ImageEntry>) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: entry.wrappedValue.image)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 60)
                .rotationEffect(.degrees(Double(entry.wrappedValue.rotation)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .animation(.spring(response: 0.3), value: entry.wrappedValue.rotation)

            let idx = entries.firstIndex(where: { $0.id == entry.id }) ?? 0
            Text("Image \(idx + 1)")
                .font(.subheadline)

            Spacer()

            Button {
                entry.rotation.wrappedValue = (entry.rotation.wrappedValue + 90) % 360
            } label: {
                Image(systemName: "rotate.right")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                withAnimation {
                    entries.removeAll { $0.id == entry.id }
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    // MARK: – Load images

    private func loadImages(_ items: [PhotosPickerItem]) {
        Task {
            var loaded: [ImageEntry] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    loaded.append(ImageEntry(image: img))
                }
            }
            entries = loaded
            savedParts = []
            savedDocument = nil
        }
    }

    private func loadFromFiles(_ urls: [URL]) {
        var loaded: [ImageEntry] = []
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                loaded.append(ImageEntry(image: img))
            }
        }
        if !loaded.isEmpty {
            entries.append(contentsOf: loaded)
            savedParts = []
            savedDocument = nil
        }
    }

    // MARK: – Convert

    private func convert() {
        Task {
            isWorking = true
            defer { isWorking = false }
            savedParts = []
            savedDocument = nil
            do {
                if mergeIntoOne {
                    let images = entries.map { rotated($0.image, by: $0.rotation) }
                    let data = try await PDFProcessingService.shared.makePDF(
                        from: images, quality: quality,
                        orientation: orientation, pageSize: pageSize, margin: margin)
                    savedDocument = try await SaveDocumentHelper.savePDF(
                        data: data, title: title, modelContext: modelContext)
                } else {
                    var records: [DocumentRecord] = []
                    for (index, entry) in entries.enumerated() {
                        let img = rotated(entry.image, by: entry.rotation)
                        let data = try await PDFProcessingService.shared.makePDF(
                            from: [img], quality: quality,
                            orientation: orientation, pageSize: pageSize, margin: margin)
                        let partTitle = "\(title) – Image \(index + 1)"
                        let record = try await SaveDocumentHelper.savePDF(
                            data: data, title: partTitle, modelContext: modelContext)
                        records.append(record)
                    }
                    savedParts = records
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    // MARK: – Rotation helper

    private func rotated(_ image: UIImage, by degrees: Int) -> UIImage {
        guard degrees != 0 else { return image }
        let radians = CGFloat(degrees) * .pi / 180
        let isQuarterTurn = (degrees == 90 || degrees == 270)
        let newSize = isQuarterTurn
            ? CGSize(width: image.size.height, height: image.size.width)
            : image.size
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            let ctx = UIGraphicsGetCurrentContext()!
            ctx.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            ctx.rotate(by: radians)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                  width: image.size.width, height: image.size.height))
        }
    }
}
