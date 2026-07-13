import SwiftData
import SwiftUI

struct PasswordToolView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sourceURL: URL?
    @State private var showPicker = false
    @State private var password = ""
    @State private var confirm = ""
    @State private var removePassword = false
    @State private var title = "Secure PDF"
    @State private var savedDocument: DocumentRecord?
    @State private var errorMessage: String?
    @AppStorage("password.encryption") private var encryption = "AES-256"

    var body: some View {
        Form {
            Section {
                Button(sourceURL?.lastPathComponent ?? "Choose PDF") { showPicker = true }
                if let sourceURL { SelectedPDFPreview(url: sourceURL) }
                Toggle("Remove password", isOn: $removePassword)
                SecureField("Password", text: $password)
                if !removePassword { SecureField("Confirm Password", text: $confirm) }
                TextField("Output name", text: $title)
            }
            if !removePassword {
                Section("Encryption") {
                    Picker("Encryption Level", selection: $encryption) {
                        Text("AES-128").tag("AES-128")
                        Text("AES-256").tag("AES-256")
                    }
                }
            }
            Section {
                PrimaryButton(title: removePassword ? "Remove Password" : "Encrypt PDF", systemImage: "lock.shield") { run() }
                    .disabled(sourceURL == nil || password.isEmpty || (!removePassword && password != confirm))
            }
        }
        .navigationTitle("PDF Password")
        .sheet(isPresented: $showPicker) {
            PDFSourcePickerSheet { sourceURL = $0.first }
        }
        .navigationDestination(item: $savedDocument) { PDFViewerView(document: $0) }
        .alert("Password", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func run() {
        guard let sourceURL else { return }
        Task {
            do {
                let data = removePassword
                    ? try await PDFProcessingService.shared.unlock(url: sourceURL, password: password)
                    : try await PDFProcessingService.shared.protect(url: sourceURL, password: password)
                savedDocument = try await SaveDocumentHelper.savePDF(data: data, title: title, modelContext: modelContext)
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
