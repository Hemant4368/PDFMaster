import PDFKit
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
    @EnvironmentObject private var shareInbox: ShareInbox
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showFilePicker = false
    @State private var entries: [ImageEntry] = []
    @State private var title = "Images PDF"
    @AppStorage("imageToPDF.quality") private var quality: PDFQuality = .balanced
    @AppStorage("imageToPDF.orientation") private var orientation: PDFPageOrientation = .portrait
    @AppStorage("imageToPDF.pageSize") private var pageSize: PDFPageSize = .a4
    @AppStorage("imageToPDF.margin") private var margin: PDFMarginSize = .none
    @AppStorage("imageToPDF.mergeIntoOne") private var mergeIntoOne = true
    @State private var savedDocument: DocumentRecord?
    @State private var savedParts: [DocumentRecord] = []
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewDocument: PDFDocument?
    @State private var isPreparingPreview = false

    private var previewHash: Int {
        var h = Hasher()
        h.combine(entries.count)
        h.combine(entries.map(\.rotation))
        h.combine(quality)
        h.combine(orientation)
        h.combine(pageSize)
        h.combine(margin)
        h.combine(mergeIntoOne)
        return h.finalize()
    }

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

            if !entries.isEmpty {
                Section("Preview") {
                    ZStack {
                        if let previewDocument {
                            PDFKitDocumentView(document: previewDocument, autoScales: true)
                        } else {
                            Color(.secondarySystemBackground)
                                .overlay { ProgressView() }
                        }
                        if isPreparingPreview && previewDocument != nil {
                            VStack {
                                HStack { Spacer(); ProgressView().padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6)) }.padding(8)
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
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
        .task {
            if let url = shareInbox.consumeURL(for: .imageToPDF),
               let data = try? Data(contentsOf: url),
               let img = UIImage(data: data) {
                entries = [ImageEntry(image: img)]
            }
        }
        .onChange(of: selectedItems) { _, newItems in loadImages(newItems) }
        .task(id: previewHash) { await generatePreview() }
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

    // MARK: – Preview

    private func generatePreview() async {
        guard !entries.isEmpty else { previewDocument = nil; return }
        isPreparingPreview = true
        defer { isPreparingPreview = false }
        do {
            let images = entries.map { rotated($0.image, by: $0.rotation) }
            let data = try await PDFProcessingService.shared.makePDF(
                from: images, quality: quality, orientation: orientation, pageSize: pageSize, margin: margin
            )
            previewDocument = PDFDocument(data: data)
        } catch {
            previewDocument = nil
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
