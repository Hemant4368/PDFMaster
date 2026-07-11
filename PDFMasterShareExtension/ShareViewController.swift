import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    // MARK: – Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Must be non-transparent so SwiftUI renders correctly inside an extension
        view.backgroundColor = UIColor.systemBackground
        showSpinner()
        loadIncomingItem()
    }

    // MARK: – Loading spinner shown while file is being read

    private func showSpinner() {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        spinner.tag = 99
    }

    private func removeSpinner() {
        view.viewWithTag(99)?.removeFromSuperview()
    }

    // MARK: – Load shared file from extensionContext

    private func loadIncomingItem() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            showError("No file was shared.")
            return
        }

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
            showError("Unsupported file type.")
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: typeID) { [weak self] url, error in
            guard let self else { return }
            guard let url, error == nil else {
                DispatchQueue.main.async { self.showError(error?.localizedDescription ?? "Could not load file.") }
                return
            }
            // Copy data while the temp URL is still valid
            guard let data = try? Data(contentsOf: url) else {
                DispatchQueue.main.async { self.showError("Could not read file.") }
                return
            }
            let filename = url.lastPathComponent
            let fileType = ShareFileType.infer(from: url)
            DispatchQueue.main.async { self.showPicker(data: data, filename: filename, fileType: fileType) }
        }
    }

    // MARK: – Show SwiftUI tool picker

    private func showPicker(data: Data, filename: String, fileType: ShareFileType) {
        removeSpinner()

        guard !fileType.tools.isEmpty else {
            showError("No tools available for this file type.")
            return
        }

        let pickerView = ShareToolPickerView(
            filename: filename,
            fileType: fileType,
            onSelect: { [weak self] toolKey in self?.finish(data: data, filename: filename, toolKey: toolKey) },
            onCancel: { [weak self] in self?.cancel() }
        )

        let hvc = UIHostingController(rootView: pickerView)
        hvc.view.backgroundColor = UIColor.systemBackground
        hvc.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hvc)
        view.addSubview(hvc.view)
        NSLayoutConstraint.activate([
            hvc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hvc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hvc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hvc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hvc.didMove(toParent: self)
    }

    // MARK: – Error state

    private func showError(_ message: String) {
        removeSpinner()
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.cancel() }
    }

    // MARK: – Save to App Group and open main app

    private func finish(data: Data, filename: String, toolKey: String) {
        let appGroupID = "group.com.hp.app.imageTopdf"

        // 1. Write file into shared container
        if let dir = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("SharedFiles", isDirectory: true) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: dir.appendingPathComponent(filename), options: .atomic)
        }

        // 2. Store pending tool in shared UserDefaults
        let ud = UserDefaults(suiteName: appGroupID)
        ud?.set(filename, forKey: "pendingShareFilename")
        ud?.set(toolKey,  forKey: "pendingShareTool")
        ud?.synchronize()

        // 3. Try to open main app via URL scheme; also complete so host app can foreground
        let safe = toolKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? toolKey
        if let url = URL(string: "pdfmaster://shareopen?tool=\(safe)") {
            extensionContext?.open(url) { [weak self] _ in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        } else {
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func cancel() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
