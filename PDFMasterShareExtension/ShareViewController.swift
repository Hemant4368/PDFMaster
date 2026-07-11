import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadIncomingItem()
    }

    // MARK: – Load shared file

    private func loadIncomingItem() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else { cancel(); return }

        // Try types in priority order
        let typeOrder = [
            UTType.pdf.identifier,
            "org.openxmlformats.wordprocessingml.document",
            "com.microsoft.word.doc",
            "org.openxmlformats.presentationml.presentation",
            "com.microsoft.powerpoint.ppt",
            "org.openxmlformats.spreadsheetml.sheet",
            "com.microsoft.excel.xls",
            "public.plain-text",
            "public.rtf",
            UTType.image.identifier,
            UTType.data.identifier,
        ]

        guard let typeID = typeOrder.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            cancel(); return
        }

        provider.loadFileRepresentation(forTypeIdentifier: typeID) { [weak self] url, error in
            guard let self, let url, error == nil,
                  let data = try? Data(contentsOf: url) else { self?.cancel(); return }
            let filename = url.lastPathComponent
            let fileType = ShareFileType.infer(from: url)
            DispatchQueue.main.async { self.showPicker(data: data, filename: filename, fileType: fileType) }
        }
    }

    // MARK: – Show SwiftUI picker

    private func showPicker(data: Data, filename: String, fileType: ShareFileType) {
        guard !fileType.tools.isEmpty else { cancel(); return }

        let pickerView = ShareToolPickerView(
            filename: filename,
            fileType: fileType,
            onSelect: { [weak self] toolKey in self?.finish(data: data, filename: filename, toolKey: toolKey) },
            onCancel: { [weak self] in self?.cancel() }
        )

        let hvc = UIHostingController(rootView: pickerView)
        hvc.view.backgroundColor = .clear
        addChild(hvc)
        view.addSubview(hvc.view)
        hvc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hvc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hvc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hvc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hvc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hvc.didMove(toParent: self)
    }

    // MARK: – Save and open main app

    private func finish(data: Data, filename: String, toolKey: String) {
        let appGroupID = "group.com.hp.app.imageTopdf"

        // Write file to shared container
        if let dir = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("SharedFiles", isDirectory: true) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: dir.appendingPathComponent(filename), options: .atomic)
        }

        // Persist pending state in shared UserDefaults
        let ud = UserDefaults(suiteName: appGroupID)
        ud?.set(filename, forKey: "pendingShareFilename")
        ud?.set(toolKey,  forKey: "pendingShareTool")
        ud?.synchronize()

        // Open main app — toolKey is PDFTool.rawValue e.g. "Compress PDF"
        let safe = toolKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? toolKey
        if let url = URL(string: "pdfmaster://shareopen?tool=\(safe)") {
            extensionContext?.open(url, completionHandler: nil)
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
